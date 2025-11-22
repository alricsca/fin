# Fin PowerShell Environment Documentation

This document provides documentation for the functions, aliases, and shims available in the Fin PowerShell environment.

## Unix Commands (`unix-commands.ps1`)

### `Select-Awk`

-   **Type:** Function
-   **Description:** A simple PowerShell implementation of the Unix awk command. It supports printing a specific field and filtering lines based on a regex pattern.
-   **Usage:** `Select-Awk -Expression <expression> [-InputObject <string>] [-FilePath <string>]`
-   **Example:** `Get-Content file.txt | Select-Awk '{print $2}'`

### `Get-Dig`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the Unix dig command. It uses `Resolve-DnsName` to get DNS records and formats the output to look like dig.
-   **Usage:** `Get-Dig -Name <string> [-Type <string>] [-Server <string>]`
-   **Example:** `Get-Dig google.com`

### `Get-NetstatEnhanced`

-   **Type:** Function
-   **Description:** An enhanced PowerShell implementation of the netstat command, providing more detailed and readable output.
-   **Usage:** `Get-NetstatEnhanced [-All] [-Listening] [-TCP] [-UDP] [-Numerical]`
-   **Example:** `Get-NetstatEnhanced -Listening`

### `Get-IpEnhanced`

-   **Type:** Function
-   **Description:** An enhanced PowerShell implementation of the ip command, providing more detailed and readable output than `ipconfig`.
-   **Usage:** `Get-IpEnhanced [-All] [-Brief] [-Interface <string>]`
-   **Example:** `Get-IpEnhanced -Brief`

### `Get-TopEnhanced`

-   **Type:** Function
-   **Description:** An enhanced PowerShell implementation of the top command, providing a continuously updating view of the top processes sorted by CPU usage.
-   **Usage:** `Get-TopEnhanced [-Count <int>] [-Continuous] [-Delay <int>]`
-   **Example:** `Get-TopEnhanced -Continuous`

### `Test-PingEnhanced`

-   **Type:** Function
-   **Description:** An enhanced PowerShell implementation of the ping command with continuous ping and timeout options.
-   **Usage:** `Test-PingEnhanced -Target <string> [-Continuous] [-Count <int>] [-Timeout <int>]`
-   **Example:** `Test-PingEnhanced google.com -Continuous`

### `Get-ProcessEnhanced`

-   **Type:** Function
-   **Description:** An enhanced PowerShell implementation of the ps command, with filtering and different view options.
-   **Usage:** `Get-ProcessEnhanced [-Name <string>] [-Full]`
-   **Example:** `Get-ProcessEnhanced -Name powershell`

### `Get-DiskFree`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the df command, summarizing disk space usage.
-   **Usage:** `Get-DiskFree [-HumanReadable] [-Drive <string>]`
-   **Example:** `Get-DiskFree -HumanReadable`

### `Get-DiskUsage`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the du command, summarizing disk usage for a path.
-   **Usage:** `Get-DiskUsage [-Path <string>] [-HumanReadable] [-Depth <int>]`
-   **Example:** `Get-DiskUsage -Path C:\Users -HumanReadable -Depth 1`

### `Get-WordCount`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the wc command, counting lines, words, and characters.
-   **Usage:** `Get-WordCount [-File <string>] [-Lines] [-Words] [-Characters]`
-   **Example:** `Get-WordCount -File file.txt`

### `Get-Head`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the head command, displaying the first few lines of a file or input.
-   **Usage:** `Get-Head [-File <string>] [-Lines <int>]`
-   **Example:** `Get-Head -File file.txt -Lines 5`

### `Get-Tail`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the tail command, displaying the last few lines of a file or input, with an option to follow file changes.
-   **Usage:** `Get-Tail [-File <string>] [-Lines <int>] [-Follow]`
-   **Example:** `Get-Tail -File file.txt -Lines 5 -Follow`

### `Get-TimeCommand`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the time command, measuring the execution time of a script block.
-   **Usage:** `Get-TimeCommand -Command <scriptblock>`
-   **Example:** `Get-TimeCommand { Start-Sleep -Seconds 2 }`

### `Get-CurlRequest`

-   **Type:** Function
-   **Description:** A wrapper for `Invoke-WebRequest` that mimics the curl command.
-   **Usage:** `Get-CurlRequest -Uri <string> [-OutFile <string>] [-Silent]`
-   **Example:** `Get-CurlRequest -Uri https://example.com -OutFile index.html`

### `Get-WgetRequest`

-   **Type:** Function
-   **Description:** A wrapper for `Invoke-WebRequest` that mimics the wget command.
-   **Usage:** `Get-WgetRequest -Uri <string> [-OutFile <string>] [-Quiet]`
-   **Example:** `Get-WgetRequest -Uri https://example.com/file.txt -OutFile file.txt`

### `Convert-Tr`

-   **Type:** Function
-   **Description:** A PowerShell implementation of the tr command, for translating or deleting characters.
-   **Usage:** `Convert-Tr -Set1 <string> -Set2 <string> [-InputObject <string>]`
-   **Example:** `'hello' | Convert-Tr 'a-z' 'A-Z'`

### `Select-Sed`

-   **Type:** Function
-   **Description:** A simple PowerShell implementation of the Unix sed command, supporting substitution.
-   **Usage:** `Select-Sed -Expression <string> [-InputObject <string>] [-File <string>]`
-   **Example:** `Get-Content file.txt | Select-Sed 's/foo/bar/g'`

### `Get-Weather`

-   **Type:** Function
-   **Description:** Gets the weather for a specified city using the `wttr.in` service.
-   **Usage:** `Get-Weather [-City <string>]`
-   **Example:** `Get-Weather -City "New York"`

### `sudo`

-   **Type:** Function and Alias
-   **Description:** Runs a command with elevated privileges. If not already administrator, it re-launches the command in a new elevated window.
-   **Usage:** `sudo <Command> [<Arguments>]`
-   **Example:** `sudo "New-Item" -Path "C:\Program Files\NewFolder" -ItemType Directory`

### `su`

-   **Type:** Function and Alias
-   **Description:** Starts a new PowerShell process as a different user, prompting for credentials.
-   **Usage:** `su <User>`
-   **Example:** `su "Administrator"`

### `gzip`

-   **Type:** Function and Alias
-   **Description:** Compresses a file using `Compress-Archive`, creating a `.gz` file.
-   **Usage:** `gzip <Path>`
-   **Example:** `gzip "file.txt"`

### `gunzip`

-   **Type:** Function and Alias
-   **Description:** Decompresses a `.gz` file using `Expand-Archive`.
-   **Usage:** `gunzip <Path>`
-   **Example:** `gunzip "file.txt.gz"`

### `scp`

-   **Type:** Function and Alias
-   **Description:** Copies a file to a remote computer using PowerShell Remoting.
-   **Usage:** `scp <Source> <Destination>`
-   **Example:** `scp "C:\local\file.txt" "remotehost:C:\remote\path"`

### `Get-Uptime`

-   **Type:** Function
-   **Alias:** `uptime`
-   **Description:** Displays the system uptime.
-   **Usage:** `Get-Uptime`
-   **Example:** `Get-Uptime`

### `Get-LSEnhanced`

-   **Type:** Function
-   **Alias:** `ls`
-   **Description:** An enhanced `ls` command that displays files and directories with colors.
-   **Usage:** `Get-LSEnhanced [-Path <string>]`
-   **Example:** `ls`

### `pkill`

-   **Type:** Function
-   **Description:** Stops processes by name.
-   **Usage:** `pkill -Name <string>`
-   **Example:** `pkill -Name "notepad"`

### `jobs`

-   **Type:** Function
-   **Description:** Lists the current background jobs.
-   **Usage:** `jobs`
-   **Example:** `jobs`

### `bg`

-   **Type:** Function
-   **Description:** Resumes a suspended background job.
-   **Usage:** `bg [-JobId <int>]`
-   **Example:** `bg` or `bg 1`

### `fg`

-   **Type:** Function
-   **Description:** Brings a background job to the foreground.
-   **Usage:** `fg [-JobId <int>]`
-   **Example:** `fg` or `fg 1`

### `md5sum`

-   **Type:** Function
-   **Description:** Calculates the MD5 hash of a file.
-   **Usage:** `md5sum -File <string>`
-   **Example:** `md5sum "file.txt"`

### `sha1sum`

-   **Type:** Function
-   **Description:** Calculates the SHA1 hash of a file.
-   **Usage:** `sha1sum -File <string>`
-   **Example:** `sha1sum "file.txt"`

### `sha256sum`

-   **Type:** Function
-   **Description:** Calculates the SHA256 hash of a file.
-   **Usage:** `sha256sum -File <string>`
-   **Example:** `sha256sum "file.txt"`

### `base64`

-   **Type:** Function
-   **Description:** Encodes or decodes data in base64 format.
-   **Usage:** `base64 [-InputObject <string>] [-Decode] [-File <string>]`
-   **Example:** `'hello' | base64` or `base64 -File "encoded.txt" -Decode`

### `alias`

-   **Type:** Function
-   **Description:** Creates or lists aliases.
-   **Usage:** `alias [<Name> <Value>]`
-   **Example:** `alias ll "Get-ChildItem -Force"` or `alias`

### `unalias`

-   **Type:** Function
-   **Description:** Removes an alias.
-   **Usage:** `unalias -Name <string>`
-   **Example:** `unalias ll`

### `export`

-   **Type:** Function
-   **Description:** Sets an environment variable.
-   **Usage:** `export -Name <string> -Value <string>`
-   **Example:** `export MY_VAR "my_value"`

### `unset`

-   **Type:** Function
-   **Description:** Removes an environment variable.
-   **Usage:** `unset -Name <string>`
-   **Example:** `unset MY_VAR`

### `source`

-   **Type:** Function
-   **Description:** Executes a script in the current scope.
-   **Usage:** `source -File <string>`
-   **Example:** `source "my_script.ps1"`

### `funced`

-   **Type:** Function
-   **Description:** Opens a function's definition in the default text editor for editing.
-   **Usage:** `funced -Name <string>`
-   **Example:** `funced Get-Weather`

### `funcsave`

-   **Type:** Function
-   **Description:** Saves a function's definition to a file in the user's profile.
-   **Usage:** `funcsave -Name <string>`
-   **Example:** `funcsave Get-Weather`

### `seq`

-   **Type:** Function
-   **Description:** Prints a sequence of numbers.
-   **Usage:** `seq <Start> [<End>] [<Increment>]`
-   **Example:** `seq 1 5`

### `yes`

-   **Type:** Function
-   **Description:** Prints a string repeatedly.
-   **Usage:** `yes [<String>]`
-   **Example:** `yes "hello"`

### `xargs`

-   **Type:** Function
-   **Description:** Builds and executes command lines from standard input.
-   **Usage:** `xargs -Command <string> [-InputObject <string>]`
-   **Example:** `echo "file1.txt file2.txt" | xargs Get-Item`

### `calc`

-   **Type:** Function
-   **Description:** Evaluates a mathematical expression.
-   **Usage:** `calc <Expression>`
-   **Example:** `calc "1 + 2"`

### `clip`

-   **Type:** Function
-   **Description:** Copies pipeline input to the clipboard.
-   **Usage:** `clip [-InputObject <string>]`
-   **Example:** `Get-Location | clip`

### `math`

-   **Type:** Function
-   **Description:** Evaluates a mathematical expression.
-   **Usage:** `math <Expression>`
-   **Example:** `math "1 + 2"`

### `reload`

-   **Type:** Function
-   **Description:** Reloads the PowerShell profile.
-   **Usage:** `reload`
-   **Example:** `reload`

### `tar`

-   **Type:** Function
-   **Description:** A wrapper for the native `tar` command.
-   **Usage:** `tar <Arguments>`
-   **Example:** `tar -cvf archive.tar file.txt`

### `grep`

-   **Type:** Function
-   **Description:** An enhanced `grep` with better parameter handling.
-   **Usage:** `grep -Pattern <string> [-InputObject <string>] [-File <string>] [-IgnoreCase] [-InvertMatch] [-LineNumber]`
-   **Example:** `grep "hello" "file.txt" -LineNumber`

## Shims (`shims.ps1`)

Shims are functions that intelligently decide whether to call a native command-line tool or a PowerShell function. This allows for a more seamless cross-platform experience.

-   `lscpu` -> `Get-CpuInfo`
-   `lsmem` -> `Get-MemoryInfo`
-   `lsusb` -> `Get-UsbInfo`
-   `lspci` -> `Get-PciInfo`
-   `dig` -> `Get-Dig`
-   `netstat` -> `Get-NetstatEnhanced`
-   `ip` -> `Get-IpEnhanced`
-   `top` -> `Get-TopEnhanced`
-   `ping` -> `Test-PingEnhanced`
-   `ps` -> `Get-ProcessEnhanced`
-   `df` -> `Get-DiskFree`
-   `du` -> `Get-DiskUsage`
-   `wc` -> `Get-WordCount`
-   `head` -> `Get-Head`
-   `tail` -> `Get-Tail`
-   `weather` -> `Get-Weather`
-   `man` -> `Invoke-ManShim`
-   `time` -> `Get-TimeCommand`
-   `curl` -> `Get-CurlRequest`
-   `wget` -> `Get-WgetRequest`
-   `awk` -> `Select-Awk`
-   `sed` -> `Select-Sed`
-   `tr` -> `Convert-Tr`
-   `pkill` -> `pkill`
-   `md5sum` -> `md5sum`
-   `sha1sum` -> `sha1sum`
-   `sha256sum` -> `sha256sum`
-   `base64` -> `base64`
-   `alias` -> `alias`
-   `unalias` -> `unalias`
-   `export` -> `export`
-   `unset` -> `unset`
-   `source` -> `source`
-   `funced` -> `funced`
-   `funcsave` -> `funcsave`
-   `seq` -> `seq`
-   `yes` -> `yes`
-   `xargs` -> `xargs`
-   `calc` -> `calc`
-   `clip` -> `clip`
-   `math` -> `math`
-   `reload` -> `reload`
-   `tar` -> `tar`
-   `history` -> `Invoke-HistoryUnified`
-   `fin` -> `fin`

## Core Functions (`fin.ps1`)

### `fin`

-   **Type:** Function
-   **Description:** The main dispatcher for Fin. It can be used to navigate directory history or view command history.
-   **Usage:**
    -   `fin -d`: Display directory history.
    -   `fin -d <index>`: Go to a specific directory in the history.
    -   `fin <search-term>`: Search command history.
-   **Example:** `fin -d` or `fin git`

### `Show-Greeting`

-   **Type:** Function
-   **Description:** Displays a greeting with system information when a new PowerShell session starts.
-   **Usage:** `Show-Greeting`
-   **Example:** `Show-Greeting`

### `Show-FirstRunInfo`

-   **Type:** Function
-   **Description:** Displays information about the available commands on the first run.
-   **Usage:** `Show-FirstRunInfo`
-   **Example:** `Show-FirstRunInfo`
