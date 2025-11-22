<#
.SYNOPSIS
  PowerShell implementations of common Unix/Linux commands for Fin.
#>

<#
.SYNOPSIS
  A simple PowerShell implementation of the Unix awk command.
.DESCRIPTION
  This function provides a basic implementation of the awk command. It supports printing a specific field and filtering lines based on a regex pattern.
.EXAMPLE
  Get-Content file.txt | Select-Awk '{print $2}'
#>
function Select-Awk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Expression,

        [Parameter(ValueFromPipeline=$true)]
        [string]$InputObject,

        [string]$FilePath
    )

    begin { $allInput = @() }
    process { if ($InputObject) { $allInput += $InputObject } }
    end {
        if ($FilePath) { $allInput = Get-Content -Path $FilePath }

        if ($Expression -match '^\s*\{\s*print\s+\$(\d+)\s*\}\s*$') {
            $fieldIndex = [int]$Matches[1] - 1
            foreach ($line in $allInput) {
                $fields = $line -split '\s+'
                if ($fieldIndex -lt $fields.Length) { $fields[$fieldIndex] }
            }
        }
        elseif ($Expression -match '^\s*/(.+)/\s*$') {
            $pattern = $Matches[1]
            $allInput | Where-Object { $_ -match $pattern }
        }
        else {
            Write-Warning "Basic AWK pattern implemented. Complex expressions may not work."
            Write-Host "Input passed through AWK filter:" -ForegroundColor $global:FinPreferences.Colors.Warning
            $allInput
        }
    }
}

<#
.SYNOPSIS
  A PowerShell implementation of the Unix dig command.
.DESCRIPTION
  This function provides a simple implementation of the dig command. It uses Resolve-DnsName to get DNS records and formats the output to look like dig.
.EXAMPLE
  Get-Dig google.com
#>
function Get-Dig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Type = "A",
        [string]$Server
    )
    try {
        $resolveParams = @{ Name = $Name; Type = $Type }
        if ($Server) { $resolveParams.DnsServer = $Server }
        $results = Resolve-DnsName @resolveParams -ErrorAction Stop
        Write-Host "`n; <<>> DiG <<>> $Name $Type" -ForegroundColor $global:FinPreferences.Colors.Info
        Write-Host "`n;; QUESTION SECTION:" -ForegroundColor $global:FinPreferences.Colors.Warning
        Write-Host ";$Name`t`t`tIN`t$Type"
        Write-Host "`n;; ANSWER SECTION:" -ForegroundColor $global:FinPreferences.Colors.Warning
        foreach ($result in $results) {
            Write-Host "$($result.Name)`t`t$($result.TTL)`tIN`t$($result.Type)`t$($result.IPAddress)"
        }
    } catch {
        Write-Error "DNS resolution failed: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
  An enhanced PowerShell implementation of the netstat command.
.DESCRIPTION
  This function provides a more detailed and readable output than the native netstat command. It can show all connections, listening ports, and filter by TCP or UDP.
.EXAMPLE
  Get-NetstatEnhanced -Listening
#>
function Get-NetstatEnhanced {
    [CmdletBinding()]
    param(
        [switch]$All,
        [switch]$Listening,
        [switch]$TCP,
        [switch]$UDP,
        [switch]$Numerical
    )

    $connections = Get-NetTCPConnection -ErrorAction SilentlyContinue
    $listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue

    if ($null -eq $connections) { Write-Warning "Could not retrieve TCP connections."; return }

    if ($All -or (-not $Listening -and -not $TCP -and -not $UDP)) {
        Write-Host "Active TCP Connections" -ForegroundColor $global:FinPreferences.Colors.Info
        Write-Host ("-" * 60) -ForegroundColor $global:FinPreferences.Colors.Info
        $connections | Format-Table LocalAddress, LocalPort, RemoteAddress, RemotePort, State -AutoSize
    }

    if ($Listening -and $listeners) {
        Write-Host "`nListening TCP Ports" -ForegroundColor $global:FinPreferences.Colors.Info
        Write-Host ("-" * 60) -ForegroundColor $global:FinPreferences.Colors.Info
        $listeners | Format-Table LocalAddress, LocalPort, State -AutoSize
    }
}

<#
.SYNOPSIS
  An enhanced PowerShell implementation of the ip command.
.DESCRIPTION
  This function provides a more detailed and readable output than the native ipconfig command. It can show all IP addresses or a brief summary.
.EXAMPLE
  Get-IpEnhanced -Brief
#>
function Get-IpEnhanced {
    [CmdletBinding()]
    param(
        [switch]$All,
        [switch]$Brief,
        [string]$Interface
    )
    $ipAddresses = Get-NetIPAddress
    if ($Brief) {
        foreach ($ip in $ipAddresses) {
            if ($ip.AddressFamily -eq 'IPv4' -and $ip.IPAddress -ne '127.0.0.1') {
                Write-Host "$($ip.InterfaceAlias): $($ip.IPAddress)" -ForegroundColor $global:FinPreferences.Colors.Success
            }
        }
    } else {
        if ($Interface) { $ipAddresses = $ipAddresses | Where-Object { $_.InterfaceAlias -like "*$Interface*" } }
        $ipAddresses | Format-Table InterfaceAlias, AddressFamily, IPAddress, PrefixLength -AutoSize
    }
}

<#
.SYNOPSIS
  An enhanced PowerShell implementation of the top command.
.DESCRIPTION
  This function provides a continuously updating view of the top processes, sorted by CPU usage.
.EXAMPLE
  Get-TopEnhanced -Continuous
#>
function Get-TopEnhanced {
    [CmdletBinding()]
    param([int]$Count = 10,[switch]$Continuous,[int]$Delay = 3)
    do {
        Clear-Host
        Write-Host "Process TOP (Refreshing every ${Delay}s) - Press Ctrl+C to exit" -ForegroundColor $global:FinPreferences.Colors.Info
        Write-Host ("=" * 80) -ForegroundColor $global:FinPreferences.Colors.Info
        $processes = Get-Process |
            Select-Object Name, CPU, WorkingSet, Id,
                @{Name="CPU(s)"; Expression={[math]::Round($_.CPU, 2)}},
                @{Name="MEM(MB)"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}} |
            Sort-Object CPU -Descending |
            Select-Object -First $Count
        $processes | Format-Table -AutoSize
        $cpuUsage = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $memory = Get-CimInstance -ClassName Win32_OperatingSystem
        $usedMemory = ($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / 1MB
        $totalMemory = $memory.TotalVisibleMemorySize / 1MB
        $memoryPercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
        Write-Host "System Summary:" -ForegroundColor $global:FinPreferences.Colors.Warning
        Write-Host ("CPU Usage: {0}% | Memory: {1}MB/{2}MB ({3}%)" -f [math]::Round($cpuUsage, 2), [math]::Round($usedMemory, 2), [math]::Round($totalMemory, 2), $memoryPercent)
        if ($Continuous) { Start-Sleep -Seconds $Delay }
    } while ($Continuous)
}

<#
.SYNOPSIS
  An enhanced PowerShell implementation of the ping command.
.DESCRIPTION
  This function provides a more detailed and readable output than the native ping command. It can ping continuously and set a timeout.
.EXAMPLE
  Test-PingEnhanced google.com -Continuous
#>
function Test-PingEnhanced {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Target,
        [switch]$Continuous,
        [int]$Count = 4,
        [int]$Timeout = 1000
    )

    $pingCount = 0
    $successCount = 0
    $totalTime = 0

    do {
        try {
            $result = Test-Connection -ComputerName $Target -Count 1 -TimeoutSeconds ($Timeout/1000) -ErrorAction Stop
            $pingCount++; $successCount++; $totalTime += $result.ResponseTime
            Write-Host ("Reply from {0}: bytes={1} time={2}ms TTL={3}" -f $result.Address, $result.BufferSize, $result.ResponseTime, $result.ResponseTimeToLive) -ForegroundColor $global:FinPreferences.Colors.Success
        } catch {
            Write-Host "Request timed out." -ForegroundColor $global:FinPreferences.Colors.Error
            $pingCount++
        }
        if (-not $Continuous -and $pingCount -ge $Count) { break }
        if ($Continuous) { Start-Sleep -Seconds 1 }
    } while ($Continuous)

    if ($pingCount -gt 0) {
        Write-Host "`nPing statistics for $Target :" -ForegroundColor $global:FinPreferences.Colors.Info
        Write-Host ("    Packets: Sent = {0}, Received = {1}, Lost = {2} ({3}% loss)," -f $pingCount, $successCount, ($pingCount - $successCount), [math]::Round((($pingCount - $successCount) / $pingCount) * 100, 2))
        if ($successCount -gt 0) {
            Write-Host ("Approximate round trip times in milli-seconds:")
            Write-Host ("    Minimum = {0}ms, Maximum = {1}ms, Average = {2}ms" -f ($result.ResponseTime), ($result.ResponseTime), [math]::Round($totalTime / $successCount, 2))
        }
    }
}

<#
.SYNOPSIS
  An enhanced PowerShell implementation of the ps command.
.DESCRIPTION
  This function provides a more detailed and readable output than the native Get-Process command. It can filter by name and show a full or brief view.
.EXAMPLE
  Get-ProcessEnhanced -Name powershell
#>
function Get-ProcessEnhanced {
    [CmdletBinding()]
    param([string]$Name,[switch]$Full)
    if ($Name) { $processes = Get-Process -Name "*$Name*" -ErrorAction SilentlyContinue } else { $processes = Get-Process }
    if ($Full) { $processes | Format-Table Id, Name, CPU, WorkingSet, Responding, StartTime -AutoSize }
    else { $processes | Format-Table Id, Name, CPU, WorkingSet -AutoSize }
}

<#
.SYNOPSIS
  A PowerShell implementation of the df command.
.DESCRIPTION
  This function provides a summary of disk space usage, similar to the Unix df command. It can display the output in a human-readable format.
.EXAMPLE
  Get-DiskFree -HumanReadable
#>
function Get-DiskFree {
    [CmdletBinding()]
    param([switch]$HumanReadable,[string]$Drive)
    if ($Drive) { $drives = Get-PSDrive -Name $Drive -ErrorAction SilentlyContinue }
    else { $drives = Get-PSDrive | Where-Object { $_.Provider -like "*FileSystem*" } }
    foreach ($drive in $drives) {
        if ($drive.Used -and $drive.Free) {
            $total = $drive.Used + $drive.Free
            $usedPercent = [math]::Round(($drive.Used / $total) * 100, 2)
            if ($HumanReadable) {
                $usedGB = [math]::Round($drive.Used / 1GB, 2)
                $freeGB = [math]::Round($drive.Free / 1GB, 2)
                $totalGB = [math]::Round($total / 1GB, 2)
                Write-Host ("{0} {1,-8} {2,6}GB {3,6}GB {4,6}GB {5,3}% {6}" -f $drive.Name, $drive.Provider, $usedGB, $freeGB, $totalGB, $usedPercent, $drive.Root)
            } else {
                Write-Host ("{0} {1,-8} {2,10} {3,10} {4,10} {5,3}% {6}" -f $drive.Name, $drive.Provider, $drive.Used, $drive.Free, $total, $usedPercent, $drive.Root)
            }
        }
    }
}

<#
.SYNOPSIS
  A PowerShell implementation of the du command.
.DESCRIPTION
  This function provides a summary of disk usage for a given path, similar to the Unix du command. It can display the output in a human-readable format and control the depth of the summary.
.EXAMPLE
  Get-DiskUsage -Path C:\Users -HumanReadable -Depth 1
#>
function Get-DiskUsage {
    [CmdletBinding()]
    param([string]$Path = ".",[switch]$HumanReadable,[int]$Depth = 2)

    function Get-FolderSize {
        param([string]$FolderPath,[int]$CurrentDepth = 0)
        if ($CurrentDepth -gt $Depth) { return 0 }
        $size = 0
        try {
            $files = Get-ChildItem -Path $FolderPath -File -ErrorAction SilentlyContinue
            foreach ($file in $files) { $size += $file.Length }
            $subdirs = Get-ChildItem -Path $FolderPath -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $subdirs) { $size += Get-FolderSize -FolderPath $dir.FullName -CurrentDepth ($CurrentDepth + 1) }
        } catch { }
        return $size
    }

    $fullPath = Resolve-Path $Path
    $totalSize = Get-FolderSize -FolderPath $fullPath
    if ($HumanReadable) {
        if ($totalSize -ge 1GB) { $displaySize = [math]::Round($totalSize / 1GB, 2); $unit = "GB" }
        elseif ($totalSize -ge 1MB) { $displaySize = [math]::Round($totalSize / 1MB, 2); $unit = "MB" }
        else { $displaySize = [math]::Round($totalSize / 1KB, 2); $unit = "KB" }
        Write-Host "$displaySize$unit`t$fullPath"
    } else {
        Write-Host "$totalSize`t$fullPath"
    }
}

<#
.SYNOPSIS
  A PowerShell implementation of the wc command.
.DESCRIPTION
  This function counts the lines, words, and characters in a file or from pipeline input, similar to the Unix wc command.
.EXAMPLE
  Get-WordCount -File file.txt
#>
function Get-WordCount {
    [CmdletBinding()]
    param([string]$File,[switch]$Lines,[switch]$Words,[switch]$Characters)
    if ($File) { $content = Get-Content -Path $File -Raw } else { $content = $Input | Out-String }
    $lineCount = 0; $wordCount = 0; $charCount = 0
    if ($content) {
        $lineCount = ($content -split "`n").Count
        $wordCount = ($content -split "\s+" | Where-Object { $_ }).Count
        $charCount = $content.Length
    }
    if ($Lines) { return $lineCount }
    if ($Words) { return $wordCount }
    if ($Characters) { return $charCount }
    Write-Host ("{0} {1} {2} {3}" -f $lineCount, $wordCount, $charCount, $File)
}

<#
.SYNOPSIS
  A PowerShell implementation of the head command.
.DESCRIPTION
  This function displays the first few lines of a file or from pipeline input, similar to the Unix head command.
.EXAMPLE
  Get-Head -File file.txt -Lines 5
#>
function Get-Head { 
    [CmdletBinding()] 
    param([string]$File,[int]$Lines = 10) 
    if ($File) { Get-Content -Path $File -TotalCount $Lines } else { $input | Select-Object -First $Lines } 
}

<#
.SYNOPSIS
  A PowerShell implementation of the tail command.
.DESCRIPTION
  This function displays the last few lines of a file or from pipeline input, similar to the Unix tail command. It also supports a -Follow switch to continuously monitor the file for new lines.
.EXAMPLE
  Get-Tail -File file.txt -Lines 5 -Follow
#>
function Get-Tail {
    [CmdletBinding()]
    param([string]$File,[int]$Lines = 10,[switch]$Follow)
    if ($File -and $Follow) {
        $position = 0
        do {
            if (Test-Path $File) {
                $content = Get-Content -Path $File
                if ($content.Count -gt $position) {
                    $content[$position..($content.Count-1)] | ForEach-Object { $_ }
                    $position = $content.Count
                }
            }
            Start-Sleep -Seconds 1
        } while ($true)
    }
    elseif ($File) { Get-Content -Path $File | Select-Object -Last $Lines }
    else { $input | Select-Object -Last $Lines }
}

<#
.SYNOPSIS
  A PowerShell implementation of the time command.
.DESCRIPTION
  This function measures the execution time of a script block, similar to the Unix time command.
.EXAMPLE
  Get-TimeCommand { Start-Sleep -Seconds 2 }
#>
function Get-TimeCommand { 
    [CmdletBinding()] 
    param([Parameter(Mandatory=$true, Position=0)][scriptblock]$Command) 
    Measure-Command -Expression $Command 
}

<#
.SYNOPSIS
  A PowerShell implementation of the curl command.
.DESCRIPTION
  This function is a wrapper for Invoke-WebRequest, providing a curl-like experience in PowerShell.
.EXAMPLE
  Get-CurlRequest -Uri https://example.com -OutFile index.html
#>
function Get-CurlRequest { 
    [CmdletBinding()] 
    param([Parameter(Mandatory=$true)][string]$Uri,[string]$OutFile,[switch]$Silent) 
    $params = @{ Uri = $Uri; UseBasicParsing = $true }; 
    if ($OutFile) { $params.OutFile = $OutFile }; 
    if ($Silent) { $params.Verbose = $false }; 
    Invoke-WebRequest @params 
}

<#
.SYNOPSIS
  A PowerShell implementation of the wget command.
.DESCRIPTION
  This function is a wrapper for Invoke-WebRequest, providing a wget-like experience in PowerShell.
.EXAMPLE
  Get-WgetRequest -Uri https://example.com/file.txt -OutFile file.txt
#>
function Get-WgetRequest { 
    [CmdletBinding()] 
    param([Parameter(Mandatory=$true)][string]$Uri,[string]$OutFile,[switch]$Quiet) 
    $params = @{ Uri = $Uri; UseBasicParsing = $true }; 
    if ($OutFile) { $params.OutFile = $OutFile }; 
    Invoke-WebRequest @params 
}

<#
.SYNOPSIS
  A PowerShell implementation of the tr command.
.DESCRIPTION
  This function translates or deletes characters from pipeline input, similar to the Unix tr command.
.EXAMPLE
  'hello' | Convert-Tr 'a-z' 'A-Z'
#>
function Convert-Tr {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Set1,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$Set2,

        [Parameter(ValueFromPipeline=$true)]
        [string]$InputObject
    )

    process {
        if ($Set1 -eq $Set2) {
            $InputObject
        } else {
            $charArray = $InputObject.ToCharArray()
            for ($i = 0; $i -lt $charArray.Length; $i++) {
                $index = $Set1.IndexOf($charArray[$i])
                if ($index -ne -1) {
                    $charArray[$i] = $Set2[$index]
                }
            }
            [string]::new($charArray)
        }
    }
}

<#
.SYNOPSIS
  A simple PowerShell implementation of the Unix sed command.
.DESCRIPTION
  This function provides a basic implementation of the sed command. It supports the 's' command for substitution.
.EXAMPLE
  Get-Content file.txt | Select-Sed 's/foo/bar/g'
#>
function Select-Sed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Expression,

        [Parameter(ValueFromPipeline=$true)]
        [string]$InputObject,

        [string]$File
    )

    begin { $allInput = @() }
    process { if ($InputObject) { $allInput += $InputObject } }
    end {
        if ($File) { $allInput = Get-Content -Path $File }

        if ($Expression -match '^s/(.+)/(.*)/([g]*)$') {
            $pattern = $Matches[1]
            $replacement = $Matches[2]
            $global = $Matches[3] -eq 'g'

            foreach ($line in $allInput) {
                if ($global) {
                    $line -replace $pattern, $replacement
                } else {
                    $line -replace $pattern, $replacement, 1
                }
            }
        } else {
            Write-Warning "Only 's' command is implemented in sed."
            $allInput
        }
    }
}

<#
.SYNOPSIS
  Gets the weather for a specified city.
.DESCRIPTION
  This function uses the wttr.in service to get the weather for a specified city.
.EXAMPLE
  Get-Weather -City "New York"
#>
function Get-Weather {
    [CmdletBinding()]
    param([string]$City = "New York")
    try {
        $url = "https://wttr.in/$City?format=3"
        Invoke-RestMethod -Uri $url
    } catch {
        Write-Error "Failed to retrieve weather for $City."
    }
}

<#
.SYNOPSIS
  A PowerShell implementation of the sudo command.
.DESCRIPTION
  This function allows you to run a command with elevated privileges. If the current user is not an administrator, it will re-launch the command in a new window with elevated privileges.
.EXAMPLE
  sudo "New-Item" -Path "C:\Program Files\NewFolder" -ItemType Directory
#>
function sudo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Command,

        [Parameter(Position=1)]
        [string[]]$Arguments
    )

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell"
        $psi.Arguments = "-Command `"$Command $Arguments`""
        $psi.Verb = "RunAs"
        $process = [System.Diagnostics.Process]::Start($psi)
        $process.WaitForExit()
    } else {
        Invoke-Expression "$Command $Arguments"
    }
}

<#
.SYNOPSIS
  A PowerShell implementation of the su command.
.DESCRIPTION
  This function allows you to start a new PowerShell process as a different user. It will prompt for the user's password.
.EXAMPLE
  su "Administrator"
#>
function su {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$User
    )

    $credential = Get-Credential -UserName $User
    Start-Process powershell -Credential $credential
}

Set-Alias -Name su -Value su -Scope Global -Force

<#
.SYNOPSIS
  A PowerShell implementation of the gzip command.
.DESCRIPTION
  This function is a wrapper for Compress-Archive, providing a gzip-like experience in PowerShell.
.EXAMPLE
  gzip "file.txt"
#>
function gzip {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )

    Compress-Archive -Path $Path -DestinationPath "$Path.gz"
}

<#
.SYNOPSIS
  A PowerShell implementation of the gunzip command.
.DESCRIPTION
  This function is a wrapper for Expand-Archive, providing a gunzip-like experience in PowerShell.
.EXAMPLE
  gunzip "file.txt.gz"
#>
function gunzip {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )

    $destination = $Path.Substring(0, $Path.Length - 3)
    Expand-Archive -Path $Path -DestinationPath $destination
}

function scp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    $session = New-PSSession -ComputerName $Destination.Split(':')[0]
    Copy-Item -Path $Source -Destination $Destination.Split(':')[1] -ToSession $session
    Remove-PSSession -Session $session
}

function Get-Uptime {
    [CmdletBinding()]
    param ()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    $days = $uptime.Days
    $hours = $uptime.Hours
    $minutes = $uptime.Minutes
    $seconds = $uptime.Seconds

    Write-Output "Uptime: $days days, $hours hours, $minutes minutes, $seconds seconds"
}

Set-Alias -Name sudo -Value sudo -Scope Global -Force
Set-Alias -Name gzip -Value gzip -Scope Global -Force
Set-Alias -Name gunzip -Value gunzip -Scope Global -Force
Set-Alias -Name scp -Value scp -Scope Global -Force
Set-Alias -Name uptime -Value Get-Uptime -Scope Global -Force



# Process Management Commands
function pkill {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process
}

function jobs {
    [CmdletBinding()]
    param()
    Get-Job
}

function bg {
    [CmdletBinding()]
    param([int]$JobId = -1)
    if ($JobId -eq -1) {
        $job = Get-Job -State Suspended | Select-Object -First 1
        if ($job) { Resume-Job $job } else { Write-Warning "No suspended jobs found" }
    } else {
        Resume-Job -Id $JobId
    }
}

function fg {
    [CmdletBinding()]
    param([int]$JobId = -1)
    if ($JobId -eq -1) {
        $job = Get-Job -State Running, Suspended | Select-Object -First 1
        if ($job) { Receive-Job -Job $job -Wait } else { Write-Warning "No jobs found" }
    } else {
        Receive-Job -Id $JobId -Wait
    }
}

# Hash Commands
function md5sum {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$File)
    if (Test-Path $File) {
        $hash = Get-FileHash -Path $File -Algorithm MD5
        Write-Output "$($hash.Hash.ToLower())  $File"
    } else {
        Write-Error "File not found: $File"
    }
}

function sha1sum {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$File)
    if (Test-Path $File) {
        $hash = Get-FileHash -Path $File -Algorithm SHA1
        Write-Output "$($hash.Hash.ToLower())  $File"
    } else {
        Write-Error "File not found: $File"
    }
}

function sha256sum {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$File)
    if (Test-Path $File) {
        $hash = Get-FileHash -Path $File -Algorithm SHA256
        Write-Output "$($hash.Hash.ToLower())  $File"
    } else {
        Write-Error "File not found: $File"
    }
}

# Encoding/Decoding
function base64 {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$InputObject,
        [switch]$Decode,
        [string]$File
    )
    
    if ($File) {
        if ($Decode) {
            $bytes = [Convert]::FromBase64String((Get-Content -Path $File -Raw))
            [System.Text.Encoding]::UTF8.GetString($bytes)
        } else {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes((Get-Content -Path $File -Raw))
            [Convert]::ToBase64String($bytes)
        }
    } else {
        if ($Decode) {
            $bytes = [Convert]::FromBase64String($InputObject)
            [System.Text.Encoding]::UTF8.GetString($bytes)
        } else {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputObject)
            [Convert]::ToBase64String($bytes)
        }
    }
}

# Shell-like Commands
function alias {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Value
    )
    
    if ($Name -and $Value) {
        Set-Alias -Name $Name -Value $Value -Scope Global
    } else {
        Get-Alias | Where-Object { $_.Source -notlike "*.dll" } | Format-Table Name, Definition -AutoSize
    }
}

function unalias {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name)
    Remove-Item -Path Alias:$Name -Force -ErrorAction SilentlyContinue
}

function export {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Value
    )
    Set-Item -Path Env:$Name -Value $Value
}

function unset {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name)
    Remove-Item -Path Env:$Name -Force -ErrorAction SilentlyContinue
}

function source {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$File)
    . $File
}

function funced {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name)
    
    $function = Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue
    if (-not $function) {
        Write-Error "Function $Name does not exist."
        return
    }
    
    $definition = $function.ScriptBlock
    $tempFile = [System.IO.Path]::GetTempFileName()
    $definition | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Open in default editor
    notepad $tempFile
    
    $newDefinition = Get-Content -Path $tempFile -Raw
    Remove-Item $tempFile
    
    if ($newDefinition -ne $definition) {
        Invoke-Expression "function $Name { $newDefinition }"
        Write-Host "Function $Name updated."
    }
}

function funcsave {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name)
    
    $function = Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue
    if (-not $function) {
        Write-Error "Function $Name does not exist."
        return
    }
    
    $profileDir = Split-Path -Path $PROFILE -Parent
    $functionsDir = Join-Path $profileDir 'Functions'
    if (-not (Test-Path $functionsDir)) {
        New-Item -ItemType Directory -Path $functionsDir -Force
    }
    
    $functionFile = Join-Path $functionsDir "$Name.ps1"
    $function.ScriptBlock | Out-File -FilePath $functionFile -Encoding UTF8
    Write-Host "Function $Name saved to $functionFile."
}

# Utility Commands
function seq {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Start,
        
        [int]$End,
        [int]$Increment = 1
    )
    
    if (-not $End) {
        $End = $Start
        $Start = 1
    }
    
    $current = $Start
    while ($current -le $End) {
        $current
        $current += $Increment
    }
}

function yes {
    [CmdletBinding()]
    param([string]$String = "y")
    while ($true) { Write-Output $String }
}

function xargs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Command,
        
        [Parameter(ValueFromPipeline=$true)]
        [string]$InputObject
    )
    
    begin { $items = @() }
    process { $items += $InputObject }
    end {
        & $Command $items
    }
}

function calc {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Expression)
    Invoke-Expression $Expression
}

function clip {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline=$true)][string]$InputObject)
    $InputObject | Set-Clipboard
}

function math {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Expression)
    Invoke-Expression $Expression
}

function reload {
    [CmdletBinding()]
    param()
    . $PROFILE
}

function tar {
    [CmdletBinding()]
    param([string[]]$Arguments)
    
    $tarCmd = Get-Command -Name tar -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $tarCmd) {
        & $tarCmd @Arguments
    } else {
        Write-Error "tar command not found. This function requires the native tar command."
    }
}

# Enhanced grep with better parameter handling
function grep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Pattern,
        
        [Parameter(ValueFromPipeline=$true)]
        [string]$InputObject,
        
        [string]$File,
        [switch]$IgnoreCase,
        [switch]$InvertMatch,
        [switch]$LineNumber
    )
    
    $params = @{
        Pattern = $Pattern
        AllMatches = $true
    }
    
    if ($IgnoreCase) { $params.CaseSensitive = $false }
    if ($InvertMatch) { $params.NotMatch = $true }
    
    if ($File) {
        if (Test-Path $File) {
            $content = Get-Content $File
            if ($LineNumber) {
                $content | Select-String @params | ForEach-Object {
                    "$($_.LineNumber):$($_.Line)"
                }
            } else {
                $content | Select-String @params
            }
        } else {
            Write-Error "File not found: $File"
        }
    } else {
        if ($LineNumber) {
            $counter = 1
            $Input | ForEach-Object {
                if ($_ -match $Pattern) {
                    "$counter`:$_"
                }
                $counter++
            }
        } else {
            $Input | Select-String @params
        }
    }
}
# SIG # Begin signature block
# MIIb5gYJKoZIhvcNAQcCoIIb1zCCG9MCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUOouKEFxrtOvldnHg190m/L4n
# stWgghZQMIIDEjCCAfqgAwIBAgIQdAYnD4MYrLRGhujoNt/icTANBgkqhkiG9w0B
# AQsFADAhMR8wHQYDVQQDDBZGaW4gUG93ZXJTaGVsbCBTY3JpcHRzMB4XDTI1MTEx
# NzA3NDYwMVoXDTMwMTExNzA3NTYwMVowITEfMB0GA1UEAwwWRmluIFBvd2VyU2hl
# bGwgU2NyaXB0czCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPAk8FRN
# SI6w6eO9Hythed5tnxb7yYcVFw73AC4RHt8zj80Bpk0v2gq+pMiV2Ao8Am2i7FxT
# lXctfW4PlV1d6jS9Wk3sYy/tQyyx9/VQL1r6vC8ALi9drv5qgyyh+v9ZPp1yI8jv
# YKimXHym+IkPVt3yFO+e28+ipRqpEmibZ6KK5VYku3BRHEtu8cYhVfpmQcUZlczZ
# LiXornLHE35yKbLHAU4MM3J8NpRyK5l7KaBC7t2a1tUOYERN1cgZPXZ3crsuNrWn
# wY4CwKoEkmh0F6hJXWfgsnsHHZK0sH32u9ycF29lJ6C2u29NuyNwepoo30/n1cAd
# dBQB8AA/yoLjvLECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMB0GA1UdDgQWBBSViq5kHi61qFl5I/jltN2rRF6gIjANBgkqhkiG
# 9w0BAQsFAAOCAQEApXjAYDytI3KmWu4ZjvV0p372GNaxaKc8pF+v0dl5uLa41Bx4
# E+1wV8QU4iuxVqQCaHTxR/IxyYvfjAqzHrSjpYIzS0dGChR9IkhO/wEuK4zloc1u
# T7un0LkBoJKhAab2cqAliVvmhcVd+qrR25zA5oY9KzXW9tttaTfflcX9WXfNpOye
# m1OX/4IqFuohQuTKxeq5bKH7l+S1tfR7NsVG9dGInmqSxzXx18s5jDc2rEzbx6Jm
# O6YXBGpHaeru/XsYd62utFOPO0A/FF1vcwgBuyEh4dF4ODLvUmszSg99WBnfQOqn
# aHWdG2NlRjzYkX2nC4n+8o+5OdAm9rC7buGLGzCCBY0wggR1oAMCAQICEA6bGI75
# 0C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAw
# MFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGln
# aUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuE
# DcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNw
# wrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs0
# 6wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e
# 5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtV
# gkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85
# tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+S
# kjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1Yxw
# LEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzl
# DlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFr
# b7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATow
# ggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiu
# HA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQE
# AwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2
# hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290
# Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/
# Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNK
# ei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHr
# lnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4
# oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5A
# Y8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNN
# n3O3AamfV6peKOK5lDCCBrQwggScoAMCAQICEA3HrFcF/yGZLkBDIgw6SYYwDQYJ
# KoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAwMDAwMFoXDTM4MDExNDIzNTk1OVow
# aTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQD
# EzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1
# NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALR4MdMK
# mEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmWgyxU7UNqEY81FzJsQqr5G7A6c+Gh
# /qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR+2fkHUiljNOqnIVD/gG3SYDE
# Ad4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPsYfwEu7EEbkC9+0F2w4QJLVSTEG8y
# AR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Zazch8NF5vp7eaZ2CVNxpqumzT
# CNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmUPAW35xUUFREmDrMxSNlr/NsJyUXz
# dtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7zL2gdFpBP9qh8SdLnEut/GcalNeJQ
# 55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rqBvKWxdCyQEEGcbLe1b8Aw4wJ
# khU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4/6vHespYMQmUiote8ladjS/nJ0+k
# 6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogxG9QEPHrPV6/7umw052AkyiLA6tQb
# Zl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbVRSX1Wd4+zoFpp4Ra+MlKM2baoD6x
# 0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMBAAGjggFdMIIBWTASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQGfHrK4pBW9i/USezLTjAfBgNV
# HSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYD
# VR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRy
# dXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwH
# ATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc/gc9EXZxML2+C8i1NKZ/zdCHxYga
# MH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk97frPBtIj+ZLzdp+yXdhOP4h
# CFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2UwM+NMvEuBd/2vmdYxDCvwzJ
# v2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntujB71WPYAgwPyWLKu6RnaID/B0ba2
# H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2rVQfjXQA1WSjjf4J2a7jLzWGNqNX
# +DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z0noDjs6+BFo+z7bKSBwZXTRNivYu
# ve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVGyOxiDf06VXxyKkOirv6o02OoXN4b
# FzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxOGLS/D284NHNboDGcmWXfwXRy4kbu
# 4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB/8MluDezooIs8CVnrpHMiD2wL40m
# m53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG2XlM9q7WP/UwgOkw/HQtyRN6
# 2JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8EA+8hcpSM9LHJmyrxaFtoza2zNaQ
# 9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43xBYLRxHanlXRoMA0GCSqGSIb3DQEB
# CwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8G
# A1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBT
# SEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAwWhcNMzYwOTAzMjM1OTU5WjBj
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMT
# MkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAy
# NSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA0EasLRLGntDqrmBW
# sytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr0cVMF3BsfAFI54um8+dnxk36
# +jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281mHrBbZHqRK71Em3/hCGC5KyyneqiZ
# 7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUueHTQKWXymOtRwJXcrcTTPPT2V1D/+
# cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw44wDcKgH+JRJE5Qg0NP3yiSyi5Mx
# gU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBSai25CFyD23DZgPfDrJJJK77epTwM
# P6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvhDU6lvJukx7jphx40DQt82yepyekl
# 4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5J4dVmVzix4A77p3awLbr89A90/nW
# GjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIUbWuhKuAeNIeWrzHKYueMJtItnj2Q
# +aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7Ce7vMRHoRon4CWIvuiNN1Lk9Y
# +xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CIDBbTRofOsNyEhzZtCGmnQigpFHti5
# 8CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQCMAAw
# HQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPPYYzoMB8GA1UdIwQYMBaAFO9vU0rp
# 5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggr
# BgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNI
# QTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZT
# SEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1s
# BwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEcJwS5rmBB7NEIRJ5jQHIh+OT2Ik/b
# NYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz9iZEN/FPsLSTwVQWo2H62yGBvg7o
# uCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwBD9R0oU62PtgxOao872bOySCI
# LdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8lD8QAGB9lctZTTOJM3pHfKBAEcxQF
# oHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42fNBVN4ueLaceRf9Cq9ec1v5iQMWT
# FQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz+BW60OiMEgV5GWoBy4RVPRwqxv7M
# k0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQTwtSSpGGhLdjnQ4eBpjtP+XB
# 3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7weCC3yXZi/uuhqdwkgVxuiMFzGVF
# wYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH3EmAp/jsJ3FVF3+d1SVDTmjFjLbN
# FZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ueIu9THFVkT+um1vshETaWyQo8gmBt
# o/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84ZPvmpovq90K8eWyG2N01c4Ih
# SOxqt81nMYIFADCCBPwCAQEwNTAhMR8wHQYDVQQDDBZGaW4gUG93ZXJTaGVsbCBT
# Y3JpcHRzAhB0BicPgxistEaG6Og23+JxMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSRZY3EGv7X
# LViS7aIcG3jKsmKJCjANBgkqhkiG9w0BAQEFAASCAQDM/LC+nftxjV4etyniVyS7
# DYULhJuQVrr4vHrDg9xlq3/yrus+5K+GV+UwsA+5Gbic4OBMEfzUy3zhemsctS+y
# qPk8/QDqyY5RHKaDBR8wMgeVgBHvoNSnOHZbwZalzwCT988ULlgc5OtCcW8mR7x/
# Nq12LnJEw2fSP8bjNINJz1CLFkZWrQdN7fJcLoxiwQ9vDiU6aXh4U82aSO5kW/c4
# C+cZlkVN7KKHPnF2hP0cX4deA5rS/ubdxnMvvJK56/3xp0Zac5d1PXdYmIyf3YoG
# WTefaD92AaTGcmzSLbDc17DbjoDkwCdKu3zFo4rSmC20M/iyB+vCCs0WUgcJ6gPJ
# oYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMwggMPAgEBMH0waTELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVz
# dGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDv
# GEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MTEyMjE5MjU0MFowLwYJKoZIhvcN
# AQkEMSIEIH7UnzihHcyQ11ptPNqB81B1Z0DPnzddgkzgrK4QQRYGMA0GCSqGSIb3
# DQEBAQUABIICAEYL+3xqw1OtAeAKDFhUSYrFH5THKAaZzOS+9r1xaAIY2p02UVha
# y0K2bRks+kEyUh/g/HruLkppv0Qb1l02yNZTd60fjS6iwwWS7mVYJPVlToO9GZL/
# zm+4sbk4VhHPKbTF0hhMJ7tsJECqKm6lJ93+7VI27+KVahr9HChoAVEpyHkawM8G
# 8ae/O3oFRGGThOu+XHEysvbxb26qXkT/Ytwph0+sz2G11oMMqmMFo6EKPdbH0CRB
# UXTUTlJierXb+tezkcsL3kwvW2RMG7gkiRQ+cLxxezOVpKQsnZwQXmprZ7LM6Z5A
# TX5v9mWuWHrXxvypAlTJStZ6xP07wz4aFo9z2/BUx95W5FU/mLdJe24DxnWRQx5q
# ajROtfKE0VHNMaVUPICKvVeaer/ReWHh2zEvDRaCzTzLFt+FphBY3vYimm2yEc2t
# 9EHal0E/7jN9kgpVvdvyI1rIWUk+1IbR4cSsmO1Ef/wCQOYD6vrxSdHeZxXeLQoj
# O+UBxVLjOh3Meo3oyAPcAqZlZGUn3nDdD+FXNKW6mivoRewnvkFwl84qkbt7ok7m
# 7UxJz3vqefNGbLYqRpqWtkkg//Sje8BAepgFOvEzHxOqJIF/LRW9XazJw1CTvh2E
# WX52VZqT9wCEJfN81DjppWFdMZLK1DuyqMwCEiDRbWrwE//26OKlghAZ
# SIG # End signature block
