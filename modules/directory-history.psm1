<#
.SYNOPSIS
  Directory history management for Fin.
#>

class FinHistoryManager {
    [System.Collections.Generic.List[string]] $History
    [int] $Index
    [string] $SavePath

    FinHistoryManager([string]$path) {
        $this.History = [System.Collections.Generic.List[string]]::new()
        $this.Index   = -1
        $this.SavePath = $path
        $this.Load()
    }

    [void] Update([string]$currentLocation) {
        if ($this.History.Count -gt 0 -and $currentLocation -eq $this.History[$this.Index]) { return }
        if ($this.Index -lt ($this.History.Count - 1)) {
            $this.History.RemoveRange(($this.Index + 1), ($this.History.Count - $this.Index - 1))
        }
        $this.History.Add($currentLocation)
        $this.Index = $this.History.Count - 1
        $this.Save()
    }

    [void] Save() {
        $data = @{ History = $this.History; Index = $this.Index }
        $json = $data | ConvertTo-Json -Depth 3
        $json | Set-Content -Path $this.SavePath -Encoding UTF8
    }

    [void] Load() {
        if (Test-Path $this.SavePath) {
            try {
                $data = Get-Content $this.SavePath -Raw | ConvertFrom-Json
                $this.History = [System.Collections.Generic.List[string]]::new()
                if ($data.History) { $this.History.AddRange($data.History) }
                $this.Index = if ($null -ne $data.Index) { $data.Index } else { -1 }
            } catch {
                $this.History = [System.Collections.Generic.List[string]]::new()
                $this.Index = -1
            }
        }
    }
}

function Get-FinHistory {
    if (-not $global:FinHistory) {
        # Requires $FinProfileDir set by the loader (fin.ps1)
        $historyPath = Join-Path $FinProfileDir 'fin_history.json'
        $global:FinHistory = [FinHistoryManager]::new($historyPath)
    }
    return $global:FinHistory
}

# Non-invasive engine event placeholder (kept for PS5 parsing stability)
Register-EngineEvent PowerShell.Exiting -Action { } | Out-Null

function n {
    $history = Get-FinHistory
    if (($history.Index + 1) -lt $history.History.Count) {
        $history.Index++
        Set-Location $history.History[$history.Index]
        $history.Save()
    }
}

function p {
    $history = Get-FinHistory
    if ($history.Index -gt 0) {
        $history.Index--
        Set-Location $history.History[$history.Index]
        $history.Save()
    }
}

function Set-LocationEnhanced {
    param([string]$Path)

    if (-not $Path) { Set-Location; return }

    if ($Path -match '^\.\.+$') {
        $levels = $Path.Length - 1
        $newPath = ([string]::Join('\', (1..$levels | ForEach-Object { '..' } )))
        Set-Location $newPath
        $history = Get-FinHistory
        $history.Update((Get-Location).ProviderPath)
        return
    }

    if ($Path -eq '-') {
        if ($global:FinLastLocation) {
            $current = Get-Location
            Set-Location $global:FinLastLocation
            $global:FinLastLocation = $current
            $history = Get-FinHistory
            $history.Update((Get-Location).ProviderPath)
            return
        } else {
            Write-Error "No previous directory stored"
            return
        }
    }

    $global:FinLastLocation = Get-Location
    Set-Location $Path
    $history = Get-FinHistory
    $history.Update((Get-Location).ProviderPath)
}

# SIG # Begin signature block
# MIIb5gYJKoZIhvcNAQcCoIIb1zCCG9MCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU98OQoLqM9soh4W8ez2caQJlh
# qt+gghZQMIIDEjCCAfqgAwIBAgIQdAYnD4MYrLRGhujoNt/icTANBgkqhkiG9w0B
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
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTBCl/lKyyX
# E+9zg8Vk0jOHsgMvBjANBgkqhkiG9w0BAQEFAASCAQBFfJsmVzGlZH8oD4HRTMfN
# Zt1ZP/Vsp/EWazcoecF5/Wo/UST+xZiHAwE3EhSW/tVLAuqNxMMtbq9zswu0ryC/
# PZZ2DrnyNJ1w5hMJ5vphXOZ12R/AuVzwUmR1beGoSd/YOYO+1RNSQ0zhJHVN01N0
# V8NE6up4xBf7xNjIG9sJHVPehqysFiyXJAJV0gkOa03nAlXSX5vQ4RCCrPz5FfMC
# dL1UgXFru4sVqhcw4dQfCnipWQM8D6dsmR4iVknZsKuh9bjJe/zXVyjaKQk48fyM
# Zw8NOYIdmyEcVvRCUVNzEprfEAWFi2XmSGlMH8y0H5l/xIIpL1M9TBBJ5x7x5wJP
# oYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMwggMPAgEBMH0waTELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVz
# dGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDv
# GEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MTEyMjE5MjUzOVowLwYJKoZIhvcN
# AQkEMSIEILUK82tGSMLowenTivWxkF7r72J0rpyY7v/s+AuY8wRyMA0GCSqGSIb3
# DQEBAQUABIICACkyEtpq05YLj1hlU4tkYTDi2JjKYwDZYPcpvbfMT0s9+yuPbzqi
# sp80bJzmpeoGQF+h4eKgJYAqyCd/aP6TpRJZtjsyqkaRss0VfOagZgWRvlud4lYC
# tPhFzFiu9uYqEP6NeFjEIvBlqs/7DaAg0/zYqOWuHc+Mhf/T2/SClqyepAjXlpnw
# zE57G4MplKu+l31pMqzf9P57ostdMj6PXycWe56SrMOUjlHWO8MO6DSlqbWfRwtR
# nM5eCZ7/MS91j1UCQY7Yap/J34RzD+OC/vZDhCUilB/a4CjHKbQ5ZiAs6Aqll896
# fkZee43Zf3zLWV6V9SDrkYs1zljUsufNzgxVxs7tQxL+g0qYbvydwQjGFqRQxvYD
# pvTaAdwCcxNx17Xw4rie5CK1/kDLaF6brTFhKVVvZnn87xbMsHB8OaeCBz+0ETdt
# zaTSZrczWkrinB/Yg8YMOb3x1CuT3vuG0l6RV4Wlonya8bqOEnXln/uZOBo6PAz9
# X3yP0FeWYIj6oft42OgWX1YQNgiVLui5Snh8NKYELmCdU7plMIYUDwDHj/VKaWzQ
# CIRkzPUGmlewBSD0KQONA6EiiaXbqWKAFdnqXVK11Cduth4VNXp3KI/f5lCTnxhM
# 1+Je5G+rH78WNo7vZqdFbxBhClxl7bOkgBr6WreihDyTiD3deTNDJH2l
# SIG # End signature block
