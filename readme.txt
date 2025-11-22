===============================================================================
 Fin: A Fish-like PowerShell Experience for Windows
===============================================================================

## What is Fin?

Fin is a single-file PowerShell script (`fin.ps1`) that enhances your PowerShell
experience by adding features and commands inspired by the Fish shell. It aims
to provide a more ergonomic and powerful command-line environment without
requiring non-native tools like WSL or Cygwin.

It is designed to be sourced directly from your PowerShell profile, making it
easy to install and manage.

## Key Features

*   **Directory History Navigation:**
    *   `fin`: Display the list of visited directories.
    *   `n`: Navigate to the *next* directory in your history.
    *   `p`: Navigate to the *previous* directory in your history.
    *   `cd ..`, `cd ...`, `cd ....`: Go up multiple directory levels.
    *   `cd -`: Go back to the last directory you were in.

*   **Enhanced Command History:**
    *   `history`: Shows the standard PowerShell session history.
    *   `history -f`: Shows the complete, persisted command history from your
      entire PowerShell usage.
    *   `full-history`: An alias for `history -f`.

*   **Unix/Linux Commands on Windows:**
    *   Provides PowerShell-native versions of common commands like `ls`, `grep`,
      `touch`, `rm`, `cp`, `mv`, `mkdir`, `cat`, `pwd`, `which`.
    *   Includes enhanced, cross-platform shims for `dig`, `netstat`, `ip`,
      `top`, `ping`, `ps`, `df`, `du`, `wc`, `head`, `tail`, and more.

*   **Custom Help:**
    *   `man fin`: Displays a custom help page for the Fin script itself.
    *   `man <command>`: For any other command, it calls the standard PowerShell
      `Get-Help`.

*   **System Information:**
    *   `sysinfo`: A convenient command to show CPU, Memory, USB, and PCI
      device information.
    *   `lscpu`, `lsmem`, `lsusb`, `lspci`: Individual info commands that work on
      Windows and fall back to native Linux tools if available.

*   **Utilities & Helpers:**
    *   `weather`: Get the current weather for any location.
    *   `math`: A simple command-line calculator.
    *   `funced`/`funcsave`: Edit and save functions in your current session.
    *   `reload`: Reload your PowerShell profile after making changes.

## Installation

1.  Place the `fin.ps1` script in a permanent location on your computer (e.g.,
    `C:\Users\YourUser\Documents\PowerShell\Fin\fin.ps1`).

2.  Find the path to your PowerShell profile. You can do this by running the
    following command in PowerShell:
    ```powershell
    echo $PROFILE
    ```

3.  If the file doesn't exist, create it:
    ```powershell
    New-Item -Path $PROFILE -ItemType File -Force
    ```

4.  Open your profile script in a text editor (e.g., `notepad $PROFILE`).

5.  Add the following line to your profile, making sure to update the path to
    where you saved `fin.ps1`:
    ```powershell
    . C:\Path\To\Your\fin.ps1
    ```

6.  Restart your PowerShell session or run `. $PROFILE` to load the script.

## Help

For more detailed information about the commands and features of Fin, run:
```powershell
man fin
```