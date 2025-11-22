param (
    [Parameter(Mandatory)]
    [string]$SourcePattern,          # e.g., '.\scripts\*.ps1'

    [Parameter(Mandatory)]
    [string]$OutputDirectory         # e.g., '.\cleaned'
)

# Ensure output directory exists
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

# Resolve matching files
$files = Get-ChildItem -Path $SourcePattern -File
if ($files.Count -eq 0) {
    Write-Host "No matching files found for pattern: $SourcePattern"
    exit 1
}

foreach ($file in $files) {
    try {
        $raw = [System.IO.File]::ReadAllBytes($file.FullName)

        # Remove UTF-8 BOM
        if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) {
            $raw = $raw[3..($raw.Length - 1)]
        }

        $text = [System.Text.Encoding]::UTF8.GetString($raw)

        # Normalize line endings to CRLF
        $text = $text -replace "`r?`n", "`r`n"

        # Remove nulls and control chars (except tab, newline, carriage return)
        $clean = ($text.ToCharArray() | Where-Object {
            ($_ -ge 32 -or $_ -eq "`t" -or $_ -eq "`n" -or $_ -eq "`r")
        }) -join ''

        # Write to output directory
        $outPath = Join-Path $OutputDirectory $file.Name
        [System.IO.File]::WriteAllText($outPath, $clean, [System.Text.Encoding]::UTF8)

        Write-Host "✔ Cleaned: $($file.Name)"
    }
    catch {
        Write-Host "✖ Failed: $($file.Name) — $_"
    }
}