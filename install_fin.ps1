<#
.SYNOPSIS
    PowerShell 5–compatible installer for Fin PowerShell environment
.DESCRIPTION
    Sets up oh-my-posh, fastfetch, profile integration, and script signing with robust logging and compatibility.
.PARAMETER VerboseOutput
    Enable detailed logging output
.PARAMETER SkipExecutionPolicy
    Skip execution policy checks
.PARAMETER ForceReinstall
    Force reinstall of all components
.EXAMPLE
    .\install_fin.ps1 -VerboseOutput
#>

[CmdletBinding()]
param(
    [switch]$VerboseOutput,
    [switch]$SkipExecutionPolicy,
    [switch]$ForceReinstall
)

$ErrorActionPreference = 'Stop'
if ($VerboseOutput) {
    $VerbosePreference = 'Continue'
    $DebugPreference   = 'Continue'
}

function Write-Log {
    param([string]$Level, [string]$Message)
    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG'   { 'Gray' }
        default   { 'White' }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Get-EnvironmentInfo {
    $edition   = $PSVersionTable.PSEdition
    $version   = $PSVersionTable.PSVersion.ToString()
    $platform  = if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { 'Win32NT' }
    $isDesktop = ($edition -eq 'Desktop') -or ($platform -eq 'Win32NT')
    return @{
        Edition   = $edition
        Version   = $version
        Platform  = $platform
        IsDesktop = $isDesktop
    }
}

function Test-IsAdmin {
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function FinEnsureExecutionPolicy {
    param([bool]$IsAdmin, [switch]$Skip)
    if ($Skip) {
        Write-Log 'INFO' 'Execution policy check skipped.'
        return
    }
    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        Write-Log 'INFO' "Current user execution policy: $currentPolicy"
        if ($currentPolicy -eq 'Restricted' -and $IsAdmin) {
            Write-Log 'INFO' 'Setting execution policy to RemoteSigned for current user'
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Log 'SUCCESS' 'Execution policy set to RemoteSigned for current user.'
        } elseif ($currentPolicy -eq 'Restricted') {
            Write-Log 'WARN' 'Execution policy is Restricted. Run as admin or manually set policy to RemoteSigned.'
        } else {
            Write-Log 'INFO' "Execution policy is already set to $currentPolicy"
        }
    } catch {
        Write-Log 'WARN' "Execution policy check failed: $($_.Exception.Message)"
    }
}

function Install-ModuleSafe {
    param([string]$Name)
    try {
        if (-not (Get-Module -ListAvailable -Name $Name)) {
            Write-Log 'INFO' "Installing module: $Name"
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
            }
            $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
            if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            }
            Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber
            Write-Log 'SUCCESS' "$Name installed."
        } else {
            Write-Log 'INFO' "$Name already installed."
        }
    } catch {
        Write-Log 'WARN' "Module install failed for ${Name}: $($_.Exception.Message)"
    }
}

function Install-WingetPackage {
    param([string]$Id, [string]$Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Log 'INFO' "Installing $Command via winget..."
        try {
            & winget install $Id -e --source winget --accept-package-agreements --accept-source-agreements
            Start-Sleep -Seconds 2
            if (Get-Command $Command -ErrorAction SilentlyContinue) {
                Write-Log 'SUCCESS' "$Command installed."
            } else {
                Write-Log 'ERROR' "Verification failed: $Command not found after install."
            }
        } catch {
            Write-Log 'ERROR' "Failed to install ${Command}: $($_.Exception.Message)"
        }
    } else {
        Write-Log 'INFO' "$Command already available."
    }
}

function EnsureProfilePath {
    param([string]$ProfilePath)
    if ([string]::IsNullOrEmpty($ProfilePath)) { 
        Write-Log 'WARN' 'Profile path is null or empty'
        return $false 
    }
    
    $profileDir = Split-Path -Parent $ProfilePath
    if (-not (Test-Path $profileDir)) {
        Write-Log 'INFO' "Creating profile directory: $profileDir"
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    if (-not (Test-Path $ProfilePath)) {
        Write-Log 'INFO' "Creating profile file: $ProfilePath"
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
        return $true
    }
    
    return $true
}

function Update-Profile {
    param([string]$ScriptRoot)
    $profilePath = $PROFILE
    
    if (-not (EnsureProfilePath -ProfilePath $profilePath)) {
        Write-Log 'WARN' 'Could not ensure PowerShell profile path. Skipping profile update.'
        return
    }
    
    $start = "# --- BEGIN FIN INTEGRATION ---"
    $end   = "# --- END FIN INTEGRATION ---"
    $escapedRoot = $ScriptRoot -replace "'", "''"
    $block = @"
$start
# Auto-generated Fin profile block
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
`$FinScriptDir = '$escapedRoot'
try {
    . (Join-Path `$FinScriptDir 'fin.ps1')
    . (Join-Path `$FinScriptDir 'Posh-Init.ps1')
} catch {
    Write-Warning "Fin profile initialization error: `$(`$_.Exception.Message)"
}
$end
"@

    try {
        # File should exist now due to EnsureProfilePath, but double-check
        if (-not (Test-Path $profilePath)) {
            Write-Log 'ERROR' "Profile file still doesn't exist after EnsureProfilePath: $profilePath"
            return
        }
        
        # Get content - handle empty files and encoding issues
        $content = ""
        $fileExistsAndHasContent = $false
        
        try {
            $existingContent = Get-Content $profilePath -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($existingContent)) {
                $content = $existingContent
                $fileExistsAndHasContent = $true
            }
        } catch {
            Write-Log 'DEBUG' "Could not read profile content or file is empty: $($_.Exception.Message)"
        }
        
        # If the file was signed, the signature block is part of the text content.
        # We must remove it before making modifications to avoid corruption.
        $wasSigned = $false
        try {
            $sig = Get-AuthenticodeSignature -FilePath $profilePath -ErrorAction SilentlyContinue
            if ($sig.Status -eq 'Valid') {
                $wasSigned = $true
                $signatureBlockPattern = "(?s)`n# SIG # Begin signature block.*# SIG # End signature block"
                if ($content -match $signatureBlockPattern) {
                    Write-Log 'INFO' 'Removing existing signature from profile content before update.'
                    $content = $content -replace $signatureBlockPattern, ''
                }
            }
        } catch {
            # Ignore signature check errors, proceed with content as-is
        }
        
        $pattern = "(?s)$([regex]::Escape($start)).*?$([regex]::Escape($end))"
        
        if ($content -match $pattern) {
            # Replace existing block
            $content = $content -replace $pattern, $block
            Write-Log 'INFO' 'Updated existing profile block.'
        } else {
            # Append new block to existing content
            if ($fileExistsAndHasContent) {
                # Add proper spacing if file already has content
                $content = $content.TrimEnd() + "`n`n$block`n"
            } else {
                # File is empty or doesn't exist - just use the block with proper newline
                $content = "$block`n"
            }
            Write-Log 'INFO' 'Added new profile block to profile.'
        }
        
        # Write the content back to the file
        Set-Content -Path $profilePath -Value $content -Encoding UTF8
        Write-Log 'SUCCESS' "Profile updated successfully at: $profilePath"
        
        if ($wasSigned) {
            Write-Log 'INFO' 'Profile was previously signed - will be re-signed after update'
        }
        
    } catch {
        Write-Log 'ERROR' "Failed to update profile: $($_.Exception.Message)"
        Write-Log 'DEBUG' "Error details: $($_.Exception.StackTrace)"
    }
}

function FinGeneratePoshInit {
    param([string]$ScriptRoot)
    $initPath = Join-Path $ScriptRoot 'Posh-Init.ps1'
    try {
        oh-my-posh init pwsh | Set-Content -Path $initPath -Encoding utf8
        Write-Log 'SUCCESS' 'Generated oh-my-posh init script.'
    } catch {
        Write-Log 'ERROR' "Failed to generate init script: $($_.Exception.Message)"
    }
}

function Add-TrustedCertificate {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [bool]$IsAdmin
    )
    if (-not $IsAdmin) {
        Write-Log 'WARN' 'Administrator rights required to trust certificate system-wide'
        return
    }
    try {
        $exportPath = Join-Path $env:TEMP "FinCert.cer"
        Export-Certificate -Cert $Certificate -FilePath $exportPath -Force | Out-Null
        Import-Certificate -FilePath $exportPath -CertStoreLocation "Cert:\CurrentUser\TrustedPeople" | Out-Null
        Write-Log 'SUCCESS' "Certificate trusted for current user."
    } catch {
        Write-Log 'WARN' "Failed to import certificate: $($_.Exception.Message)"
    } finally {
        Remove-Item $exportPath -ErrorAction SilentlyContinue
    }
}

function Get-OrCreateCertificate {
    param([string]$ScriptRoot, [bool]$IsAdmin)

    $subject = "CN=Fin PowerShell Scripts"
    $thumbprintPath = Join-Path $ScriptRoot 'fin-cert.thumbprint'
    $cert = $null

    # Try stored thumbprint first
    if (Test-Path $thumbprintPath) {
        try {
            $storedThumbprint = (Get-Content $thumbprintPath -Raw).Trim()
            if ($storedThumbprint) {
                $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
                    Where-Object { $_.Thumbprint -eq $storedThumbprint -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) } |
                    Select-Object -First 1
                if ($cert) {
                    Write-Log 'INFO' "Using stored certificate: $($cert.Thumbprint)"
                } else {
                    Write-Log 'WARN' "Stored thumbprint not found/expired. Regenerating."
                    Remove-Item $thumbprintPath -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Log 'WARN' "Failed reading thumbprint file: $($_.Exception.Message)"
        }
    }

    # Fallback: search by subject
    if (-not $cert) {
        $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
            Where-Object { $_.Subject -eq $subject -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object NotAfter -Descending |
            Select-Object -First 1
    }

    if (-not $cert) {
        try {
            $cert = New-SelfSignedCertificate `
                -Subject $subject `
                -Type CodeSigningCert `
                -CertStoreLocation "Cert:\CurrentUser\My" `
                -KeyUsage DigitalSignature `
                -KeyAlgorithm RSA `
                -KeyLength 2048 `
                -NotAfter (Get-Date).AddYears(5)
            Write-Log 'SUCCESS' "Created new certificate: $($cert.Thumbprint)"
        } catch {
            Write-Log 'ERROR' "Certificate creation failed: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Log 'INFO' "Found certificate by subject: $($cert.Thumbprint)"
    }

    # Persist thumbprint
    try {
        Set-Content -Path $thumbprintPath -Value $cert.Thumbprint
        Write-Log 'INFO' "Stored certificate thumbprint to: $thumbprintPath"
    } catch {
        Write-Log 'WARN' "Failed to store thumbprint: $($_.Exception.Message)"
    }

    # Trust certificate if admin
    if ($IsAdmin) {
        Add-TrustedCertificate -Certificate $cert -IsAdmin $IsAdmin
    } else {
        Write-Log 'WARN' "Run as administrator to auto-trust certificate for the current user."
    }

    return $cert   # Always return the actual certificate object
}

function FinSignScripts {
    param([object]$Cert, [string[]]$Files)

    if (-not $Cert) {
        Write-Log 'WARN' 'No certificate provided. Skipping script signing.'
        return
    }

    if ($Cert -is [System.Object[]]) {
        $Cert = $Cert | Select-Object -First 1
        Write-Log 'WARN' "Multiple certificates detected. Using first: $($Cert.Thumbprint)"
    }

    if ($Cert -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
        Write-Log 'ERROR' "Invalid certificate object supplied to signing. Type: $($Cert.GetType().FullName)"
        return
    }

    foreach ($file in $Files) {
        if (Test-Path $file) {
            try {
                # Check current signature status
                $currentSig = Get-AuthenticodeSignature -FilePath $file -ErrorAction SilentlyContinue
                if ($currentSig.Status -eq 'Valid') {
                    Write-Log 'DEBUG' "Re-signing already signed file: $(Split-Path $file -Leaf)"
                }
                
                Set-AuthenticodeSignature -FilePath $file -Certificate $Cert -TimestampServer "http://timestamp.digicert.com" -ErrorAction Stop | Out-Null
                Write-Log 'SUCCESS' "Signed: $(Split-Path $file -Leaf)"
            } catch {
                Write-Log 'WARN' "Failed to sign ${file}: $($_.Exception.Message)"
            }
        } else {
            Write-Log 'WARN' "File not found: $file"
        }
    }
}

function Start-FinInstall {
    $envInfo = Get-EnvironmentInfo
    $isAdmin = Test-IsAdmin
    
    if ($PSScriptRoot) {
        $scriptRoot = $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        Write-Log 'ERROR' "Could not determine script root. Please run this script from a file."
        return
    }

    Write-Log 'INFO' "PowerShell Edition: $($envInfo.Edition), Platform: $($envInfo.Platform), Version: $($envInfo.Version)"
    Write-Log 'INFO' "Admin: $isAdmin"
    Write-Log 'INFO' "Script Root: $scriptRoot"

    FinEnsureExecutionPolicy -IsAdmin $isAdmin -Skip:$SkipExecutionPolicy

    Install-ModuleSafe -Name 'PSReadLine'
    Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Command 'oh-my-posh'
    Install-WingetPackage -Id 'fastfetch.fastfetch' -Command 'fastfetch'

    FinGeneratePoshInit -ScriptRoot $scriptRoot
    Update-Profile -ScriptRoot $scriptRoot

    $cert = Get-OrCreateCertificate -ScriptRoot $scriptRoot -IsAdmin $isAdmin

    $files = @(
        (Join-Path $scriptRoot 'fin.ps1'),
        (Join-Path $scriptRoot 'Posh-Init.ps1')
    )

    if (-not [string]::IsNullOrEmpty($PROFILE) -and (Test-Path $PROFILE -ErrorAction SilentlyContinue)) {
        $files += $PROFILE
    }

    $modulesDir = Join-Path $scriptRoot 'modules'
    if (Test-Path $modulesDir) {
       $moduleFiles = Get-ChildItem $modulesDir -Include *.ps1,*.psm1 -File -Recurse -ErrorAction SilentlyContinue
       if ($moduleFiles) {
            $files += $moduleFiles.FullName
        }
    }

    FinSignScripts -Cert $cert -Files $files

    Write-Log 'SUCCESS' 'Fin environment setup complete. Restart your PowerShell session to apply all changes.'
}

Start-FinInstall