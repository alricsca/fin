Here is the `fin.md` file, structured as a design document and developer manual for this project.

---

# `fin.md`: A Fish-like PowerShell Experience (Windows-Native)

## 1. Executive Summary & Guiding Principles

This document outlines the implementation plan for "Project Gemini," a series of PowerShell scripts and modules designed to bring the ergonomics and key features of the `fish` shell to a **Windows-native** PowerShell 7 environment.

The goal is **not** to create a 1:1 port or a POSIX-compatibility layer. The goal is to build a *fish-like* experience using **PowerShell-idiomatic** solutions.

**Guiding Principles:**

1.  **Windows-Native First:** All solutions must rely on PowerShell modules (like `PSReadLine`, `oh-my-posh`), .NET classes, or Windows APIs. No `WSL`, `Cygwin`, or other Linux pseudo-environments will be used.
2.  **Use the Platform:** Do not reinvent a feature if a robust, idiomatic PowerShell equivalent exists. For example, `param()` blocks are the (superior) equivalent of `argparse`. `PSReadLine` is the equivalent of `bind`.
3.  **Document, Don't Obfuscate:** For features that have a direct PowerShell-native equivalent (e.g., `if`, `for`), this manual will document the correct PowerShell syntax rather than attempting to create unstable aliases. This is to "avoid developers going astray," as requested.
4.  **Modularity:** New features should be implemented as discrete functions or modules that can be loaded via the user's `$PROFILE`.

---

## 2. Part 1: Documentation & Equivalency (The "Manual")

This section documents features that will **not** be implemented, primarily because PowerShell provides a direct, native, and often more powerful equivalent. Attempting to alias or wrap these would be counter-productive.

### 2.1 Core Language Constructs (No Implementation)

These `fish` commands are fundamental language keywords. PowerShell has its own equivalent grammar, which must be used.

fish Keyword

PowerShell Equivalent

Notes

`function`

`function`

Syntax is different, but the concept is identical.

`if`, `else`

`if`, `else`, `elseif`

PowerShell's `if` requires `( )` and `{ }`.

`for`

`foreach` / `for`

PS `foreach ($item in $collection)` is the most common equivalent.

`while`

`while`

Nearly identical in function.

`switch`, `case`

`switch`

PowerShell's `switch` is significantly more powerful (regex, wildcards, etc.).

`begin`, `end`

`{ }` (Script Blocks)

PowerShell uses script blocks for code grouping, not `begin`/`end` keywords.

`break`, `continue`

`break`, `continue`

Functionally identical.

`return`

`return`

PowerShell also implicitly returns any non-captured output.

`try`, `catch`

`try`, `catch`, `finally`

PowerShell's error handling structure.

### 2.2 Shell Operators (No Implementation)

These are parsing-level operators.

fish Operator

PowerShell Equivalent

Notes

`and`

`&&` or `-and`

`&&` is a pipeline chain operator. `-and` is a logical operator for `if`.

`or`

`

`not`

`!` or `-not`

`!` and `-not` are logical operators.

### 2.3 Platform-Specific Exclusions (No Implementation)

These `fish` commands are specific to the Unix/Linux system model and do not have a direct equivalent in the Windows/NT model.

-   `umask`: Windows does not use a "file creation mode mask." It uses **Access Control Lists (ACLs)**. The native PowerShell way to manage this is with `Get-Acl` and `Set-Acl`.
-   `ulimit`: This is a *nix concept for setting resource limits on a process. This is managed by Windows at the OS level and is not typically configurable from a shell.
-   `isatty`: This checks if a file descriptor is a terminal. PowerShell's equivalent concept would be checking `$Host.UI.SupportsVirtualTerminal` or `[Console]::IsOutputRedirected`, but it's not a 1:1 match.

---

## 3. Part 2: Implementation Plan (Complex Features)

This section details the design for porting complex `fish` subsystems using PowerShell-native tools.

### 3.1 Subsystem: Prompt & VCS (Git)

-   **Fish Commands:** `fish_prompt`, `fish_right_prompt`, `fish_git_prompt`, `fish_vcs_prompt`
-   **PowerShell Solution:** **oh-my-posh**
-   **Justification:** The modern PowerShell ecosystem has standardized on `oh-my-posh` for rich, themeable, high-performance prompts. It is Windows-native, supports all common shells, and has extremely deep Git integration. Re-inventing this would be a massive, redundant effort.
-   **Action Plan:**
    1.  This project will **not** attempt to replicate `fish_prompt`.
    2.  The "manual" will designate `oh-my-posh` as the official solution.
    3.  Installation: `winget install JanDeDobbeleer.OhMyPosh`
    4.  Profile configuration: `oh-my-posh init pwsh | Invoke-Expression`.

### 3.2 Subsystem: Directory History

-   **Fish Commands:** `cdh`, `dirh`, `prevd`, `nextd`
-   **PowerShell Solution:** A custom implementation using a global `ArrayList` and a function "hook" on `Set-Location`.
-   **Justification:** PowerShell tracks directory history via `pushd`/`popd` (the stack), but not in the linear, browsable way `fish` does. We must build this.
-   **Action Plan:**
    1.  **Data Store (in `$PROFILE`):**
        
        ```powershell
        $global:GeminiDirectoryHistory = [System.Collections.Generic.List[string]]::new()$global:GeminiDirectoryIndex = -1
        ```
        
    2.  **The Hook (in `$PROFILE`):** We must subscribe to the `PSReadLine` "On-Enter" event. This is the most reliable way to capture the directory *after* a command has run.
        
        ```powershell
        Register-EngineEvent -SourceIdentifier 'PowerShell.OnPromptCommand' -Action {    $currentLocation = (Get-Location).Path    $lastLocation = $global:GeminiDirectoryHistory[$global:GeminiDirectoryHistory.Count - 1]    if ($currentLocation -ne $lastLocation) {        # If we were browsing history, truncate the "future"        if ($global:GeminiDirectoryIndex -lt ($global:GeminiDirectoryHistory.Count - 1)) {            $global:GeminiDirectoryHistory.RemoveRange(                ($global:GeminiDirectoryIndex + 1),                ($global:GeminiDirectoryHistory.Count - $global:GeminiDirectoryIndex - 1)            )        }                $global:GeminiDirectoryHistory.Add($currentLocation)        $global:GeminiDirectoryIndex = $global:GeminiDirectoryHistory.Count - 1    }}
        ```
        
    3.  **Function Implementation (in `fin.ps1`):**
        -   `dirh`: `function dirh { $global:GeminiDirectoryHistory }`
        -   `cdh`: (This is for interactive selection in fish, which is complex. A simple start is to just list the history) `Set-Alias -Name cdh -Value dirh`
        -   `prevd`:
            
            ```powersall
            function prevd {    if ($global:GeminiDirectoryIndex -gt 0) {        $global:GeminiDirectoryIndex--        Set-Location $global:GeminiDirectoryHistory[$global:GeminiDirectoryIndex]    }}
            ```
            
        -   `nextd`:
            
            ```powersall
            function nextd {    if ($global:GeminiDirectoryIndex -lt ($global:GeminiDirectoryHistory.Count - 1)) {        $global:GeminiDirectoryIndex++        Set-Location $global:GeminiDirectoryHistory[$global:GeminiDirectoryIndex]    }}
            ```
            

### 3.3 Subsystem: Keybindings

-   **Fish Commands:** `bind`, `fish_vi_key_bindings`, `fish_key_reader`
-   **PowerShell Solution:** `PSReadLine` Module
-   **Justification:** Keybindings are handled 100% by the `PSReadLine` module, which is default in PowerShell. We can create simple wrapper functions to provide a `fish`-like *feel* while using the correct, native cmdlets.
-   **Action Plan:**
    1.  **Mode Switching:**
        -   `fish_vi_key_bindings`: `Set-PSReadLineOption -EditMode Vi`
        -   `fish_default_key_bindings`: `Set-PSReadLineOption -EditMode Emacs`
    2.  **Wrapper Function (in `alias.ps1`):**
        
        ```powershell
        function bind {    param(        [string]$Key,        [scriptblock]$ScriptBlock    )    Set-PSReadLineKeyHandler -Key $Key -ScriptBlock $ScriptBlock}# Example: bind 'Ctrl+h' { Get-History }
        ```
        
    3.  **Key Reader:**
        -   `fish_key_reader`: The `PSReadLine` equivalent is `[Console]::ReadKey()`. We can create an alias.
        -   `Set-Alias -Name fish_key_reader -Value Read-Host` (A simpler, more direct equivalent).

### 3.4 Subsystem: Configuration & Function Editing

-   **Fish Commands:** `fish_config`, `funced`, `funcsave`
-   **PowerShell Solution:** Direct manipulation of the `$PROFILE` file.
-   **Justification:** In PowerShell, the "config" *is* the `$PROFILE` file(s). Functions are "saved" by being in this file. We can create utilities to make editing this easier.
-   **Action Plan:**
    1.  `fish_config`: Create a function that opens the user's `$PROFILE` in their default editor.
        
        ```powershell
        function fish_config {    # Assumes VS Code is preferred, but could just be Invoke-Item    code $PROFILE}
        ```
        
    2.  `funced`: A true `funced` (editing a function in memory) would require complex AST parsing. A pragmatic, 80/20 solution is to just open the `$PROFILE` file.
        -   `Set-Alias -Name funced -Value fish_config`
    3.  `funcsave`: This concept is not applicable. We will document that functions are "saved" by being placed in the `$PROFILE`.

### 3.5 Subsystem: Debugging

-   **Fish Commands:** `breakpoint`
-   **PowerShell Solution:** Native debugging cmdlets.
-   **Justification:** PowerShell has a mature, built-in debugging engine.
-   **Action Plan:**
    1.  This will be documentation-only.
    2.  `breakpoint` -> `Set-PSBreakpoint` (e.g., `Set-PSBreakpoint -Script $PROFILE -Line 10`)
    3.  PowerShell also provides `Wait-Debugger`, `Enter-PSHostProcess`, and a full debugging experience in VS Code.

### 3.6 Utility Functions & Idioms



This covers remaining commands that are idiomatic to `fish`.



-   **`argparse`, `fish_opt`:**

    -   **PS Solution:** `param()` block.

    -   **Action:** Document that the `param()` block at the top of a script or function is the native, more powerful equivalent.

-   **`status`:**

    -   **PS Solution:** `$?` (boolean success) and `$LASTEXITCODE` (integer).

    -   **Action:** Document the use of these automatic variables.

-   **`psub` (Process Substitution):**

    -   **PS Solution:** `$(...)` (Sub-expressions).

    -   **Action:** Document that commands like `Get-Content (which.exe $command)` are the native equivalent of `cat (psub which $command)`.

-   **`string` (String Manipulation):**

    -   **PS Solution:** The alias file from the previous step implements this.

    -   **Action:** Continue to use the `string-lower`, `string-upper`, `string-split`, etc. functions already created, as they map well to .NET string methods.



### 3.7 Help System



-   **Fish Command:** `man`

-   **PowerShell Solution:** A custom shim function that intercepts `man fin` and passes other requests to `Get-Help`.

-   **Justification:** The `fin` script has its own set of features that warrant a dedicated help file. The `man` command is the most intuitive way for users to access this help.

-   **Action Plan:**

    1.  **Create `fin-help.txt`:** A dedicated help file for `fin`'s features.

    2.  **Create `Invoke-ManShim`:** A PowerShell function that:

        -   Checks if the first argument is `fin`.

        -   If it is, it displays the content of `fin-help.txt`.

        -   Otherwise, it calls `Get-Help` with the provided arguments.

    3.  **Create Shim:** Use `New-InteropShim` to create a `man` command that points to `Invoke-ManShim`.



---


