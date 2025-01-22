# Installation Stage Functions
Set-StrictMode -Version 3.0

function Install-WindowsUtility {
    [CmdletBinding()]
    param()
    
    Write-Status "Running Windows setup utility..." -Status "Starting" -Color "Yellow"
    
    try {
        Write-Host "Running Windows setup utility..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm christitus.com/win | iex`"" -Wait -Verb RunAs
        
        Write-Host "`nPlease review and complete the Windows setup utility configuration." -ForegroundColor Yellow
        if (Get-UserConfirmation "Did you successfully complete the Windows setup utility configuration?") {
            Set-StageFlag "windows-utility"
            Write-Status "Windows setup utility" -Status "Completed" -Color "Green"
            return $true
        }
        return $false
    } catch {
        Write-Warning "Windows setup utility encountered an error: $_"
        Write-Host "You can try running it manually by opening a new PowerShell window and running:" -ForegroundColor Yellow
        Write-Host "irm christitus.com/win | iex" -ForegroundColor Cyan
        return $false
    }
}

function Install-WindowsActivation {
    [CmdletBinding()]
    param()
    
    Write-Status "Running Windows activation..." -Status "Starting" -Color "Yellow"
    
    if (-not (Invoke-ExternalCommand -Command 'irm https://get.activated.win | iex' -Description "Windows Activation" -UseShell)) {
        return $false
    }
    
    Write-Host "`nPlease verify that Windows was activated correctly." -ForegroundColor Yellow
    if (Get-UserConfirmation "Was Windows activated successfully?") {
        Set-StageFlag "windows-activation"
        Write-Status "Windows activation" -Status "Completed" -Color "Green"
        return $true
    }
    return $false
}

function Install-PersonalRepositories {
    [CmdletBinding()]
    param()
    
    Write-Status "Setting up personal repositories..." -Status "Starting" -Color "Yellow"
    
    # Create parent directories if needed
    $repoParentPath = "$env:USERPROFILE\repo"
    if (-not (Test-Path $repoParentPath)) {
        New-Item -ItemType Directory -Path $repoParentPath -Force | Out-Null
        Write-Status "Created repositories directory" -Status "Done" -Color "Green"
    }
    
    # Setup Neovim config
    $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
    if (-not (Install-Repository -RepoUrl "https://github.com/PaysanCorrezien/config.nvim.git" -TargetPath $nvimConfigPath)) {
        return $false
    }
    
    # Setup WezTerm config
    $weztermConfigPath = "$env:USERPROFILE\repo\config.wezterm"
    if (-not (Install-Repository -RepoUrl "https://github.com/PaysanCorrezien/config.wezterm" -TargetPath $weztermConfigPath)) {
        return $false
    }
    
    # Setup and configure Chezmoi
    if (-not (Install-Chezmoi)) {
        return $false
    }
    
    Set-StageFlag "personal-repos-setup"
    Write-Status "Personal repositories setup" -Status "Completed" -Color "Green"
    return $true
}

function Install-CLIUtilities {
    [CmdletBinding()]
    param()
    
    Write-Status "Installing CLI utilities..." -Status "Starting" -Color "Yellow"
    
    # Install Winget packages
    $cliUtils = @(
        @{Id = "rsteube.Carapace"; Description = "Command completion"},
        @{Id = "Slackadays.Clipboard"; Description = "Clipboard manager"},
        @{Id = "Gitleaks.Gitleaks"; Description = "Git secrets scanner"},
        @{Id = "lsd-rs.lsd"; Description = "LSDeluxe"},
        @{Id = "Starship.Starship"; Description = "Prompt"},
        @{Id = "XAMPPRocky.tokei"; Description = "Code metrics"},
        @{Id = "JohnMacFarlane.Pandoc"; Description = "Document converter"},
        @{Id = "Yubico.YubikeyManager"; Description = "Yubikey Manager"},
        @{Id = "Yubico.Authenticator"; Description = "Yubikey Authenticator"},
        @{Id = "sharkdp.fd"; Description = "File finder"},
        @{Id = "SSHFS-Win.SSHFS-Win"; Description = "SSHFS for Windows"},
        @{Id = "astral-sh.uv"; Description = "Python package installer"},
        @{Id = "sigoden.AIChat"; Description = "AI Chat client"},
        @{Id = "NickeManarin.ScreenToGif"; Description = "Screen recorder"},
        @{Id = "Gyan.FFmpeg"; Description = "Media toolkit"},
        @{Id = "ImageMagick.ImageMagick"; Description = "Image processing"}
    )
    
    foreach ($util in $cliUtils) {
        if (-not (Install-WithWinget -PackageId $util.Id)) {
            Write-Warning "Failed to install $($util.Description)"
            return $false
        }
    }
    
    # Install Scoop packages
    Write-Host "`nInstalling Scoop packages..." -ForegroundColor Yellow
    $scoopPackages = @(
        @{Name = "termusic"; Description = "Terminal music player"},
        @{Name = "ouch"; Description = "Archive utility"},
        @{Name = "extras/musicbee"; Description = "Music player"}
    )
    
    foreach ($package in $scoopPackages) {
        if (-not (Invoke-ExternalCommand -Command "scoop install $($package.Name)" -Description "Installing $($package.Description)")) {
            Write-Warning "Failed to install $($package.Description)"
            return $false
        }
    }
    
    # Install Atuin via Cargo
    if (-not (Invoke-ExternalCommand -Command "cargo install atuin" -Description "Installing Atuin")) {
        return $false
    }
    
    # Install BusyGit via pip
    if (-not (Invoke-ExternalCommand -Command "python -m pip install git+https://github.com/PaysanCorrezien/BusyGit.git" -Description "Installing BusyGit")) {
        return $false
    }

    # Install Rust Analyzer
    if (-not (Invoke-ExternalCommand -Command "rustup component add rust-analyzer" -Description "Installing Rust Analyzer")) {
        return $false
    }
    
    # Configure environment paths
    $pathsToAdd = @(
        @{
            Path = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-7.1-full_build\bin"
            Description = "FFmpeg"
        },
        @{
            Path = "$env:USERPROFILE\repo\windows.config\apps\rustscan-2.3.0-x86_64-windows"
            Description = "RustScan"
        },
        @{
            Path = "C:\Program Files\SSHFS-Win\bin"
            Description = "SSHFS"
        },
        @{
            Path = "C:\Program Files\KeePassXC"
            Description = "KeePassXC CLI"
        },
        @{
            Path = "C:\Program Files\Yubico\YubiKey Manager"
            Description = "YubiKey Manager"
        }
    )

    foreach ($pathItem in $pathsToAdd) {
        if (Test-Path $pathItem.Path) {
            Write-Host "Adding $($pathItem.Description) to PATH..." -ForegroundColor Yellow
            Set-Env "Path" "$($pathItem.Path);$(Get-Env 'Path')" "User"
        } else {
            Write-Warning "Path not found for $($pathItem.Description): $($pathItem.Path)"
        }
    }
    
    Write-Host "`nNote: Yubikey Login needs to be installed manually from the Yubico website" -ForegroundColor Yellow
    Write-Host "Visit: https://www.yubico.com/products/yubico-login-for-windows/" -ForegroundColor Cyan
    
    Set-StageFlag "cli-utils-setup"
    Write-Status "CLI utilities installation" -Status "Completed" -Color "Green"
    return $true
}

# Export functions
$exports = @{
    'Install-WindowsUtility' = ${function:Install-WindowsUtility}
    'Install-WindowsActivation' = ${function:Install-WindowsActivation}
    'Install-PersonalRepositories' = ${function:Install-PersonalRepositories}
    'Install-CLIUtilities' = ${function:Install-CLIUtilities}
}

return $exports 