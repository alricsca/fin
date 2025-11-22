@echo off
setlocal

REM Check if a file path is provided
if "%~1"=="" (
    echo Usage: %~n0 [file_to_sign]
    exit /b 1
)

REM Use the provided file path
set "file_to_sign=%~1"

REM --- Configuration ---
REM Path to your private key
set "private_key=d:\GoogleDriveAlricsca\KOTHPC\Desktop\ScriptLocker\key.pem"
REM Path to your public key (optional, for verification)
set "public_key=d:\GoogleDriveAlricsca\KOTHPC\Desktop\ScriptLocker\pubkey.pem"
REM Output signature file path
set "signature_file=%file_to_sign%.sig"

REM --- Signing ---
echo Signing %file_to_sign%...
openssl dgst -sha256 -sign "%private_key%" -out "%signature_file%" "%file_to_sign%"

if %errorlevel% neq 0 (
    echo Failed to sign the file.
    exit /b 1
)

echo Signature saved to %signature_file%

REM --- Verification (Optional) ---
echo Verifying signature...
openssl dgst -sha256 -verify "%public_key%" -signature "%signature_file%" "%file_to_sign%"

if %errorlevel% neq 0 (
    echo Verification failed.
    exit /b 1
)

echo Verification successful.

endlocal
