# System Configuration Functions
Set-StrictMode -Version 3.0

function Set-FinalSystemConfigurations {
    [CmdletBinding()]
    param()
    
    Write-Status "Applying final system configurations..." -Status "Starting" -Color "Yellow"
    
    # Configure Git SSH command
    if (-not (Invoke-ExternalCommand -Command 'git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"' -Description "Configuring Git SSH command")) {
        return $false
    }
    Write-Status "Git SSH configuration" -Status "Completed" -Color "Green"
    
    # Configure startup programs
    Write-Host "`nConfiguring startup programs..." -ForegroundColor Yellow
    $startupFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
    $glazeWMPath = Join-Path $startupFolder "GlazeWM.lnk"
    
    if (Test-Path $glazeWMPath) {
        Write-Host "Adding GlazeWM to startup programs..." -ForegroundColor Yellow
        Copy-Item $glazeWMPath "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\" -Force
        Write-Status "GlazeWM startup configuration" -Status "Completed" -Color "Green"
    } else {
        Write-Warning "GlazeWM shortcut not found at expected location: $glazeWMPath"
    }
    
    # Install WezTerm float version if requested
    Write-Host "`nWould you like to install the custom float version of WezTerm?" -ForegroundColor Yellow
    if (Get-UserConfirmation "Install custom WezTerm float version?") {
        $weztermFloatScript = Join-Path $PSScriptRoot "..\scripts\install-wezterm-float.ps1"
        if (Test-Path $weztermFloatScript) {
            if (-not (Invoke-ExternalCommand -Command "& '$weztermFloatScript'" -Description "Installing WezTerm float version")) {
                return $false
            }
            Write-Status "WezTerm float version" -Status "Installed" -Color "Green"
        } else {
            Write-Warning "WezTerm float installation script not found at: $weztermFloatScript"
        }
    }
    
    # Rename computer if requested
    $currentName = $env:COMPUTERNAME
    Write-Host "`nCurrent computer name: $currentName" -ForegroundColor Yellow
    Write-Host "Would you like to rename your computer? If yes, provide a new name." -ForegroundColor Yellow
    $newName = Read-Host "Enter new computer name (or press Enter to skip)"
    
    if ($newName -and ($newName -ne $currentName)) {
        if (-not (Invoke-ExternalCommand -Command "Rename-Computer -NewName '$newName' -Force" -Description "Renaming computer")) {
            return $false
        }
        Write-Host "`nComputer has been renamed to '$newName'. A restart will be required for this change to take effect." -ForegroundColor Yellow
    }
    
    Set-StageFlag "final-system-config"
    Write-Status "Final system configurations" -Status "Completed" -Color "Green"
    return $true
}

function Set-OpenSSH {
    [CmdletBinding()]
    param()
    
    Write-Status "Setting up OpenSSH..." -Status "Starting" -Color "Yellow"
    if (Test-Command "ssh") {
        Write-Status "OpenSSH" -Status "Already installed" -Color "Green"
        return $true
    }
    
    # Install OpenSSH Client
    if (-not (Invoke-ExternalCommand -Command 'Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0' -Description "Installing OpenSSH Client")) {
        return $false
    }
    
    # Configure SSH Agent service
    if (-not (Invoke-ExternalCommand -Command 'Set-Service -Name ssh-agent -StartupType Automatic' -Description "Configuring SSH Agent")) {
        return $false
    }
    
    if (-not (Invoke-ExternalCommand -Command 'Start-Service ssh-agent' -Description "Starting SSH Agent")) {
        return $false
    }
    
    Write-Status "OpenSSH setup" -Status "Completed" -Color "Green"
    return $true
}

function Update-ConfigurationRepositories {
    [CmdletBinding()]
    param()
    
    Write-Status "Updating configuration repositories..." -Status "Starting" -Color "Yellow"
    
    $configRepos = @(
        @{
            Path = Join-Path $env:USERPROFILE "repo\config.wezterm"
            Description = "WezTerm Configuration"
        },
        @{
            Path = Join-Path $env:USERPROFILE "repo\pythonautomation"
            Description = "Python Automation Scripts"
        },
        @{
            Path = Join-Path $env:USERPROFILE ".local\share\chezmoi"
            Description = "Chezmoi Dotfiles"
        },
        @{
            Path = Join-Path $env:LOCALAPPDATA "nvim"
            Description = "Neovim Configuration"
        }
    )
    
    $success = $true
    foreach ($repo in $configRepos) {
        if (-not (Test-Path $repo.Path)) {
            Write-Warning "$($repo.Description) not found at: $($repo.Path)"
            continue
        }
        
        Push-Location $repo.Path
        try {
            Write-Host "Updating $($repo.Description)..." -ForegroundColor Yellow
            
            # Check for unstaged changes
            $status = git status --porcelain
            if ($status) {
                Write-Host "Unstaged changes found in $($repo.Description):" -ForegroundColor Yellow
                git status --short
                
                # Ask user what to do with changes
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Commit", "Commit and push changes")
                    [System.Management.Automation.Host.ChoiceDescription]::new("S&tash", "Stash changes and pull")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Ignore", "Skip this repository")
                )
                
                $decision = $Host.UI.PromptForChoice("", "What would you like to do with these changes?", $choices, 2)
                
                switch ($decision) {
                    0 { # Commit and push
                        $commitMsg = Read-Host "Enter commit message"
                        git add .
                        git commit -m $commitMsg
                        git push
                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "Failed to push changes for $($repo.Description)"
                            $success = $false
                            continue
                        }
                    }
                    1 { # Stash
                        git stash
                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "Failed to stash changes for $($repo.Description)"
                            $success = $false
                            continue
                        }
                    }
                    2 { # Skip
                        Write-Host "Skipping $($repo.Description)" -ForegroundColor Yellow
                        continue
                    }
                }
            }
            
            # Check SSH key setup
            $sshTest = git ls-remote origin HEAD 2>&1
            if ($LASTEXITCODE -ne 0 -and $sshTest -match "Permission denied \(publickey\)") {
                Write-Warning "SSH key is not properly configured for $($repo.Description)"
                Write-Host "`nPlease:" -ForegroundColor Yellow
                Write-Host "1. Ensure your SSH key is in KeePassXC" -ForegroundColor Yellow
                Write-Host "2. KeePassXC SSH Agent integration is enabled" -ForegroundColor Yellow
                Write-Host "3. Your SSH key is loaded in KeePassXC" -ForegroundColor Yellow
                Write-Host "4. Try running: ssh -T git@github.com" -ForegroundColor Yellow
                $success = $false
                continue
            }
            
            # Fetch latest changes
            git fetch origin
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to fetch updates for $($repo.Description)"
                $success = $false
                continue
            }
            
            # Get current branch
            $currentBranch = git rev-parse --abbrev-ref HEAD
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to get current branch for $($repo.Description)"
                $success = $false
                continue
            }
            
            # Pull changes
            git pull origin $currentBranch
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to pull updates for $($repo.Description)"
                $success = $false
                continue
            }
            
            Write-Host "$($repo.Description) updated successfully" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to update $($repo.Description): $_"
            $success = $false
        }
        finally {
            Pop-Location
        }
    }
    
    Write-Status "Configuration updates" -Status "Completed" -Color "Green"
    return $success
}

function Set-DevMode {
    [CmdletBinding()]
    param (
        [switch]$Force
    )

    begin {
        # Check for admin privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            throw "This function requires administrative privileges. Please run PowerShell as Administrator."
        }
    }

    process {
        try {
            # Create an array of registry changes to make
            $registryChanges = @(
                # Developer Mode
                @{
                    Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
                    Name = "AllowDevelopmentWithoutDevLicense"
                    Type = "DWORD"
                    Value = 1
                },
                # Sudo (Inline Mode)
                @{
                    Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo"
                    Name = "Enabled"
                    Type = "DWORD"
                    Value = 3  # Inline mode
                },
                # PowerShell Execution Policy
                @{
                    Path = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell"
                    Name = "ExecutionPolicy"
                    Type = "String"
                    Value = "Unrestricted"
                }
            )

            # Apply each registry change
            foreach ($change in $registryChanges) {
                # Ensure the registry path exists
                if (-not (Test-Path $change.Path)) {
                    New-Item -Path $change.Path -Force | Out-Null
                }

                # Create or update the registry value
                New-ItemProperty -Path $change.Path -Name $change.Name -PropertyType $change.Type -Value $change.Value -Force | Out-Null
            }

            # Set execution policy using PowerShell command as well (belt and suspenders approach)
            Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force:$Force

            # Output success message
            Write-Host "Development environment has been configured successfully:" -ForegroundColor Green
            Write-Host "✓ Developer Mode enabled" -ForegroundColor Green
            Write-Host "✓ Sudo command enabled (inline mode)" -ForegroundColor Green
            Write-Host "✓ PowerShell execution policy set to Unrestricted" -ForegroundColor Green
            Write-Host "`nNote: Some changes may require a system restart to take effect." -ForegroundColor Yellow
            return $true
        }
        catch {
            Write-Error "Failed to configure development environment: $_"
            return $false
        }
    }
}

# Export functions
$exports = @{
    'Set-FinalSystemConfigurations' = ${function:Set-FinalSystemConfigurations}
    'Set-OpenSSH' = ${function:Set-OpenSSH}
    'Update-ConfigurationRepositories' = ${function:Update-ConfigurationRepositories}
    'Set-DevMode' = ${function:Set-DevMode}
}

return $exports 