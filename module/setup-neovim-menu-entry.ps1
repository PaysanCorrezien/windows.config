# Requires administrator privileges
#Requires -RunAsAdministrator
#Requires -PSEdition Core
#Requires -Version 7.0

Set-StrictMode -Version 3.0

function Add-NeovimContextMenu {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$MenuName = "Edit with Neovim",
        [Parameter(Mandatory=$false)]
        [string]$ScriptPath = $PSScriptRoot
    )

    try {
        $nvimCommand = Join-Path $ScriptPath "nvim-wezterm.bat"
        
        Write-Verbose "Script path: $ScriptPath"
        Write-Verbose "Nvim command path: $nvimCommand"

        if (!(Test-Path $nvimCommand)) {
            throw "nvim-wezterm.bat not found at: $nvimCommand"
        }

        # Create context menu entry
        Write-Verbose "Creating context menu entry..."
        $menuCmd = "reg add `"HKEY_CLASSES_ROOT\*\shell\EditWithNeovim`" /ve /d `"$MenuName`" /f"
        $result = cmd /c $menuCmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create menu entry: $result"
        }

        # Create command
        Write-Verbose "Creating command entry..."
        $cmdValue = "`"$nvimCommand`" `"%1`""
        $commandCmd = "reg add `"HKEY_CLASSES_ROOT\*\shell\EditWithNeovim\command`" /ve /d `"$cmdValue`" /f"
        $result = cmd /c $commandCmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create command: $result"
        }

        Write-Host "Context menu entry added successfully"
        return $true
    } catch {
        Write-Error "Failed to create context menu entry: $_"
        return $false
    }
}

function Get-CurrentFileAssociation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Extension
    )

    $ext = $Extension.TrimStart(".")
    Write-Verbose "Checking current association for .$ext"
    
    $result = cmd /c "assoc .$ext" 2>&1
    return $result
}

function Set-FileAssociation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$FileExtensions,
        [Parameter(Mandatory=$false)]
        [string]$ScriptPath = $PSScriptRoot,
        [Parameter(Mandatory=$false)]
        [switch]$VerifyAssociations
    )

    try {
        $nvimCommand = Join-Path $ScriptPath "nvim-wezterm.bat"
        Write-Verbose "Script path: $ScriptPath"
        Write-Verbose "Nvim command path: $nvimCommand"

        if (!(Test-Path $nvimCommand)) {
            throw "nvim-wezterm.bat not found at: $nvimCommand"
        }

        foreach ($ext in $FileExtensions) {
            $ext = $ext.TrimStart(".")
            Write-Verbose "Setting up file association for .$ext"

            if ($VerifyAssociations) {
                $currentAssoc = Get-CurrentFileAssociation -Extension $ext
                Write-Host "`nCurrent association for .$ext is: $currentAssoc"
                
                $Title    = 'File Association Verification'
                $Question = 'Do you want to register Neovim for this file type?'
                $Choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Register Neovim")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Skip")  
                )
                $Decision = $Host.UI.PromptForChoice($Title, $Question, $Choices, 0)
                
                if ($Decision -eq 1) {
                    Write-Host "Skipping .$ext"
                    continue
                }
            }

            # Define file type and program ID
            $fileType = "NvimWezterm.$ext"

            # Create file type with command
            $cmdValue = "`"$nvimCommand`" `"%1`""
            $result = cmd /c "ftype $fileType=`"$cmdValue`"" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to create file type for .$ext - $($result)"
                continue
            }

            # Set up Applications registration for "Open with" menu
            $appPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.$ext"
            
            # Create Application entry
            $result = cmd /c "reg add `"$appPath\OpenWithList`" /v a /d `"nvim-wezterm.bat`" /f" 2>&1
            $result = cmd /c "reg add `"$appPath\OpenWithProgids`" /v `"$fileType`" /t REG_NONE /d `"`" /f" 2>&1

            Write-Host "Successfully registered Neovim for .$ext"
        }

        # Notify the system about the file association changes
        cmd /c "ie4uinit.exe -show"
        
        Write-Host "`nNeovim has been registered as an available application for the selected file types."
        Write-Host "You can now choose it from the 'Open with' menu for these file types."
        
        return $true
    } catch {
        Write-Error "Failed to register file associations: $_"
        return $false
    }
}

# Example usage:
# Add-NeovimContextMenu -Verbose
# Set-FileAssociation -FileExtensions @("txt", "md", "json") -VerifyAssociations -Verbose

# Run the function if script is executed directly
if ($MyInvocation.InvocationName -eq '.\setup-neovim-menu-entry.ps1') {
    Add-NeovimContextMenu -Verbose
} 