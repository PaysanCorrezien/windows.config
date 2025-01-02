# Requires administrator privileges
#Requires -RunAsAdministrator
#Requires -PSEdition Core
#Requires -Version 7.0

Set-StrictMode -Version 3.0

# Import utility functions
$utils = . "$PSScriptRoot\utils.ps1"
${function:Write-Log} = $utils['Write-Log']

function Add-NeovimContextMenu {
    [CmdletBinding()]
    param()

    try {
        $scriptPath = Split-Path -Parent $PSScriptRoot
        Write-Verbose "Script path: $scriptPath"
        
        # Look for nvim-wezterm.bat in the scripts directory
        $nvimCommand = Join-Path $scriptPath "scripts\nvim-wezterm.bat"
        Write-Verbose "Nvim command path: $nvimCommand"
        
        if (-not (Test-Path $nvimCommand)) {
            throw "nvim-wezterm.bat not found at: $nvimCommand"
        }

        # Create registry entries for the context menu
        $registryPath = "Registry::HKEY_CLASSES_ROOT\*\shell\nvim"
        
        # Create the main menu entry
        New-Item -Path $registryPath -Force | Out-Null
        Set-ItemProperty -Path $registryPath -Name "(default)" -Value "Edit with Neovim"
        Set-ItemProperty -Path $registryPath -Name "Icon" -Value "nvim-qt.exe"
        
        # Create the command entry
        New-Item -Path "$registryPath\command" -Force | Out-Null
        Set-ItemProperty -Path "$registryPath\command" -Name "(default)" -Value "`"$nvimCommand`" `"%1`""
        
        return $true
    }
    catch {
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

# Return a hashtable of functions
@{
    'Add-NeovimContextMenu' = ${function:Add-NeovimContextMenu}
    'Get-CurrentFileAssociation' = ${function:Get-CurrentFileAssociation}
    'Set-FileAssociation' = ${function:Set-FileAssociation}
} 