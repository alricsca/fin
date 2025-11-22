<#
.SYNOPSIS
  Cross-platform system inventory for Fin, built from scratch.

.DESCRIPTION
  Provides CPU, memory, USB, and PCI device inspectors with consistent, scriptable output.
  - Windows: Uses CIM/WMI and PnP associations with safe fallbacks.
  - Linux/macOS: Uses common CLI tools (lscpu, lsmem/free, lsusb, lspci) if present.

.NOTES
  Design goals:
  - No interactive prompts; predictable switches.
  - Raw mode returns data objects/strings for automation.
  - Format mode returns formatted tables (Windows) or passthrough text (Unix).
  - Default mode prints readable summaries.
#>

#region helpers

function Test-IsWindows {
    [CmdletBinding()]
    param()
    return $PSVersionTable.PSEdition -eq 'Desktop' -and $env:OS -eq 'Windows_NT'
}

function Test-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    $cmd = Get-Command -Name $Name -ErrorAction SilentlyContinue
    return ($null -ne $cmd)
}

function New-Table {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Data,
        [string[]]$Columns
    )
    if (Test-IsWindows) {
        if ($Columns) { return $Data | Format-Table -Property $Columns -AutoSize }
        return $Data | Format-Table -AutoSize
    } else {
        # On non-Windows, emit a compact text table with -join spacing
        $lines = @()
        if ($Columns) {
            $lines += ($Columns -join ' | ')
            $lines += ('-' * ($lines[0].Length))
            foreach ($row in $Data) {
                $values = foreach ($c in $Columns) { $row.$c }
                $lines += ($values -join ' | ')
            }
        } else {
            foreach ($row in $Data) { $lines += ($row | Out-String).Trim() }
        }
        return $lines
    }
}

function Write-Heading {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)
    Write-Host "`n$Text" -ForegroundColor Cyan
}

function Render-Object {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$InputObject,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Template,

        [string]$ForegroundColor = 'White'
    )

    foreach ($item in $InputObject) {
        foreach ($formatString in $Template.Keys) {
            $propNames = $Template[$formatString]
            # Ensure propValues is an array for the -f operator
            $propValues = @($propNames | ForEach-Object { $item.$_ })
            try {
                $line = $formatString -f $propValues
                Write-Host $line -ForegroundColor $ForegroundColor
            } catch {
                Write-Warning "Failed to format line: $formatString. Error: $($_.Exception.Message)"
            }
        }
    }
}

#endregion helpers

#region CPU

function global:Get-CpuInfo {
    [CmdletBinding()]
    param(
        [switch]$Format,
        [switch]$Raw
    )

    try {
        if (Test-IsWindows) {
            $cpuCim = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
            $result = foreach ($c in $cpuCim) {
                [PSCustomObject]@{
                    Name              = ($c.Name -replace '\s+', ' ').Trim()
                    Vendor            = $c.Manufacturer
                    Sockets           = $cpuCim.Count
                    Cores             = $c.NumberOfCores
                    Threads           = $c.NumberOfLogicalProcessors
                    BaseClockMHz      = $c.MaxClockSpeed
                    L2CacheKB         = $(if ($c.L2CacheSize -and $c.L2CacheSize -gt 0) { $c.L2CacheSize } else { 0 })
                    L3CacheKB         = $(if ($c.L3CacheSize -and $c.L3CacheSize -gt 0) { $c.L3CacheSize } else { 0 })
                    Architecture      = (Get-CimInstance Win32_ComputerSystem).SystemType
                }
            }
            if ($Format) { return New-Table -Data $result -Columns @('Name','Vendor','Cores','Threads','BaseClockMHz','L3CacheKB') }
            return $result
        }

        if (Test-Command -Name 'lscpu') {
            return (& lscpu 2>$null)
        } else {
            Write-Warning 'CPU info unavailable: lscpu not found.'
            return $null
        }
    } catch {
        Write-Warning ("Get-CpuInfo error: {0}" -f $_.Exception.Message)
        return $null
    }
}

#endregion CPU

#region Memory

function global:Get-MemoryInfo {
    [CmdletBinding()]
    param(
        [switch]$Format,
        [switch]$Raw,
        [switch]$Summary
    )

    try {
        if (Test-IsWindows) {
            $modules = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
            $items = foreach ($m in $modules) {
                $gb = [math]::Round([double]$m.Capacity / 1GB, 2)
                [PSCustomObject]@{
                    Slot         = $m.DeviceLocator
                    CapacityGB   = $gb
                    SpeedMHz     = $(if ($m.Speed) { [int]$m.Speed } else { $null })
                    Vendor       = $m.Manufacturer
                    PartNumber   = $m.PartNumber
                    FormFactor   = $m.FormFactor
                }
            }

            if ($Summary) {
                $total = ($items | Measure-Object -Property CapacityGB -Sum).Sum
                return [PSCustomObject]@{
                    TotalGB   = [math]::Round($total, 2)
                    Modules   = $items.Count
                }
            }

            if ($Format) { return New-Table -Data $items -Columns @('Slot','CapacityGB','SpeedMHz','Vendor','PartNumber') }
            return $items
        }

        # Non-Windows
        if ($Summary -and (Test-Command -Name 'free')) {
            return (& free -h 2>$null)
        }

        if (Test-Command -Name 'lsmem') {
            $ar = @()
            if ($Summary) { $ar += '--summary' }
            return (& lsmem $ar 2>$null)
        } elseif (Test-Command -Name 'free') {
            return (& free -h 2>$null)
        } else {
            Write-Warning 'Memory info unavailable: lsmem/free not found.'
            return $null
        }
    } catch {
        Write-Warning ("Get-MemoryInfo error: {0}" -f $_.Exception.Message)
        return $null
    }
}

#endregion Memory

#region USB

function global:Get-UsbInfo {
    [CmdletBinding()]
    param(
        [switch]$Format,
        [switch]$Raw,
        [switch]$Tree,
        [string]$VendorId,
        [string]$ProductId
    )

    try {
        if (Test-IsWindows) {
            # Enumerate USB controllers and associated PnP entities
            $entities = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
                        Where-Object { $_.PNPDeviceID -like 'USB*' -and $_.Status -eq 'OK' }

            $items = foreach ($e in $entities) {
                $vid = $null; $pnpid = $null
                if ($e.PNPDeviceID -match 'VID_([0-9A-F]{4})') { $vid = $Matches[1] }
                if ($e.PNPDeviceID -match 'PID_([0-9A-F]{4})') { $pnpid = $Matches[1] }
                if ($VendorId -and $vid -ne $VendorId) { continue }
                if ($ProductId -and $pnpid -ne $ProductId) { continue }

                [PSCustomObject]@{
                    Name       = $(if ($e.Name) { $e.Name } else { $e.Caption })
                    VendorId   = $(if ($vid) { $vid } else { 'N/A' })
                    ProductId  = $(if ($pnpid) { $pnpid } else { 'N/A' })
                    DeviceId   = $e.PNPDeviceID
                    Class      = $e.Class
                }
            }

            if ($Format) { return New-Table -Data $items -Columns @('Name','VendorId','ProductId','Class') }
            # Tree view is a special format, handle it here for now
            if ($Tree) {
                $lines = @("USB topology:")
                foreach ($i in $items) {
                    $label = "{0} (VID:{1} PID:{2})" -f $i.Name, $i.VendorId, $i.ProductId
                    $lines += ("|-- " + $label)
                }
                return $lines -join "`n"
            }
            return $items
        }

        if (Test-Command -Name 'lsusb') {
            $ar = @()
            if ($Tree) { $ar += '-t' }
            if ($VendorId -or $ProductId) { $ar += '-v' }
            $text = & lsusb $ar 2>$null

            if ($VendorId -or $ProductId) {
                $filtered = foreach ($line in $text) {
                    $ok = $true
                    if ($VendorId -and $line -notmatch "idVendor.*$VendorId") { $ok = $false }
                    if ($ProductId -and $line -notmatch "idProduct.*$ProductId") { $ok = $false }
                    if ($ok) { $line }
                }
                $text = $filtered
            }
            return $text
        } else {
            Write-Warning 'USB info unavailable: lsusb not found.'
            return $null
        }
    } catch {
        Write-Warning ("Get-UsbInfo error: {0}" -f $_.Exception.Message)
        return $null
    }
}

#endregion USB

#region PCI

function Get-PciCategory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$NameOrDesc)

    switch -regex ($NameOrDesc.ToLower()) {
        'net|ethernet|wireless|wifi' { return 'Network' }
        'display|graphics|video|vga' { return 'Display' }
        'audio|sound|hdmi'           { return 'Audio' }
        'storage|nvme|sata|raid'     { return 'Storage' }
        'usb'                         { return 'USB' }
        default                       { return 'Other' }
    }
}

function global:Get-PciInfo {
    [CmdletBinding()]
    param(
        [switch]$Format,
        [switch]$Raw,
        [switch]$Vbose,
        [string]$Class,
        [string]$Vendor
    )

    try {
        if (Test-IsWindows) {
            $pnp = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
                   Where-Object { $_.PNPDeviceID -like 'PCI*' -and $_.Status -eq 'OK' }

            $items = foreach ($d in $pnp) {
                $text = ("$(if ($d.Name) { $d.Name } else { '' })" + ' ' + "$(if ($d.Description) { $d.Description } else { '' })").Trim()
                $cat = Get-PciCategory -NameOrDesc $text
                if ($Class -and ($cat -notmatch $Class)) { continue }
                if ($Vendor -and ($text -notmatch $Vendor)) { continue }

                $obj = [PSCustomObject]@{
                    Name        = $(if ($d.Name) { $d.Name } else { $d.Description })
                    Description = $d.Description
                    Status      = $d.Status
                    Category    = $cat
                    DeviceId    = $d.PNPDeviceID
                }

                if ($Vbose) { $obj } else {
                    [PSCustomObject]@{
                        Name     = $obj.Name
                        Category = $obj.Category
                        Status   = $obj.Status
                    }
                }
            }

            if ($Format) {
                $cols = if ($Vbose) { @('Name','Description','Status','Category','DeviceId') } else { @('Name','Category','Status') }
                return New-Table -Data $items -Columns $cols
            }
            return $items
        }

        if (Test-Command -Name 'lspci') {
            $ar = @()
            if ($Vbose) { $ar += '-v' }
            $text = & lspci @ar 2>$null
            if ($Vendor) { $text = $text | Where-Object { $_ -match $Vendor } }
            if ($Class)  { $text = $text | Where-Object { $_ -match $Class } }
            return $text
        } else {
            Write-Warning 'PCI info unavailable: lspci not found.'
            return $null
        }
    } catch {
        Write-Warning ("Get-PciInfo error: {0}" -f $_.Exception.Message)
        return $null
    }
}

#endregion PCI

#region sysinfo orchestrator

function sysinfo {
    [CmdletBinding()]
    param(
        [switch]$Summary,
        [switch]$Raw
    )

    # --- Templates for Rendering ---
    $cpuTemplate = [ordered]@{
        "CPU: {0} ({1})" = @('Name', 'Vendor')
        "  Sockets: {0}  Cores: {1}  Threads: {2}" = @('Sockets', 'Cores', 'Threads')
        "  Base: {0} MHz  L3: {1} KB" = @('BaseClockMHz', 'L3CacheKB')
    }
    $memTemplate = [ordered]@{
        "  {0}: {1} GB @ {2} MHz [{3} {4}]" = @('Slot', 'CapacityGB', 'SpeedMHz', 'Vendor', 'PartNumber')
    }
    $memSummaryTemplate = [ordered]@{
        "Memory: {0} GB across {1} modules" = @('TotalGB', 'Modules')
    }
    $usbTemplate = [ordered]@{
        "  {0}  VID:{1} PID:{2}" = @('Name', 'VendorId', 'ProductId')
    }
    $pciCatTemplate = [ordered]@{
        "`n{0}:" = @('Name')
    }
    $pciDevTemplate = [ordered]@{
        "  {0}" = @('Name')
    }
    $pciDevVerboseTemplate = [ordered]@{
        "  {0}" = @('Name')
        "    Status: {0}" = @('Status')
    }
    $summaryDeviceTemplate = [ordered]@{
        "Devices: {0} USB, {1} PCI" = @('UsbCount', 'PciCount')
    }

    try {
        if ($Raw) {
            return [PSCustomObject]@{
                CPU    = Get-CpuInfo
                Memory = Get-MemoryInfo
                USB    = Get-UsbInfo
                PCI    = Get-PciInfo
            }
        }

        if ($Summary) {
            Write-Heading -Text 'System summary'
            $cpu = Get-CpuInfo
            if ($cpu -is [System.Collections.IEnumerable] -and $cpu -isnot [string]) { $cpu = $cpu | Select-Object -First 1 }
            if ($cpu) {
                if ($cpu -isnot [string]) {
                    Render-Object -InputObject $cpu -Template $cpuTemplate -ForegroundColor Green
                }
            }

            $mem = Get-MemoryInfo -Summary
            if ($mem) {
                if ($mem -isnot [string]) {
                    Render-Object -InputObject $mem -Template $memSummaryTemplate -ForegroundColor Green
                } else {
                    Write-Host $mem -ForegroundColor Green
                }
            }

            $usbCount = 0
            $pciCount = 0
            $usbRaw = Get-UsbInfo
            if ($usbRaw) {
                if ($usbRaw -is [System.Collections.IEnumerable] -and $usbRaw -isnot [string[]]) { $usbCount = ($usbRaw | Measure-Object).Count }
                elseif ($usbRaw -is [string[]] -or $usbRaw -is [string]) { $usbCount = ($usbRaw -split "`n").Count }
            }
            $pciRaw = Get-PciInfo
            if ($pciRaw) {
                if ($pciRaw -is [System.Collections.IEnumerable] -and $pciRaw -isnot [string[]]) { $pciCount = ($pciRaw | Measure-Object).Count }
                elseif ($pciRaw -is [string[]] -or $pciRaw -is [string]) { $pciCount = ($pciRaw -split "`n").Count }
            }
            $deviceSummary = [PSCustomObject]@{ UsbCount = $usbCount; PciCount = $pciCount }
            Render-Object -InputObject $deviceSummary -Template $summaryDeviceTemplate -ForegroundColor Green
            return
        }

        # --- Default Detailed View ---

        Write-Heading -Text 'CPU info'
        $cpuInfo = Get-CpuInfo
        if ($cpuInfo) {
            if ($cpuInfo -isnot [string]) {
                Render-Object -InputObject $cpuInfo -Template $cpuTemplate -ForegroundColor Green
            } else {
                Write-Host $cpuInfo -ForegroundColor Green
            }
        }

        Write-Heading -Text 'Memory info'
        $memInfo = Get-MemoryInfo
        if ($memInfo) {
            if ($memInfo -isnot [string]) {
                Write-Host "Memory modules:" -ForegroundColor Green
                Render-Object -InputObject $memInfo -Template $memTemplate -ForegroundColor White
            } else {
                Write-Host $memInfo -ForegroundColor Green
            }
        }

        Write-Heading -Text 'USB devices'
        $usbInfo = Get-UsbInfo
        if ($usbInfo) {
            if ($usbInfo -isnot [string]) {
                Write-Host "USB devices:" -ForegroundColor Green
                Render-Object -InputObject $usbInfo -Template $usbTemplate -ForegroundColor White
            } else {
                Write-Host $usbInfo -ForegroundColor Green
            }
        }

        Write-Heading -Text 'PCI devices'
        $pciInfo = Get-PciInfo -Vbose:$false
        if ($pciInfo) {
            if ($pciInfo -isnot [string]) {
                Write-Host "PCI devices:" -ForegroundColor Green
                $groups = $pciInfo | Group-Object Category
                $devTemplate = if ($false) { $pciDevVerboseTemplate } else { $pciDevTemplate }
                foreach ($g in $groups) {
                    Render-Object -InputObject $g -Template $pciCatTemplate -ForegroundColor Yellow
                    Render-Object -InputObject $g.Group -Template $devTemplate -ForegroundColor White
                }
            } else {
                Write-Host $pciInfo -ForegroundColor Green
            }
        }
    } catch {
        Write-Warning ("sysinfo error: {0}" -f $_.Exception.Message)
    }
}

#endregion sysinfo
