# Installation Stage Functions
Set-StrictMode -Version 3.0

function Install-WindowsUtility
{
  [CmdletBinding()]
  param()
    
  Write-Status "Running Windows setup utility..." -Status "Starting" -Color "Yellow"
    
  try
  {
    Write-Host "Running Windows setup utility..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm christitus.com/win | iex`"" -Wait -Verb RunAs
        
    Write-Host "`nPlease review and complete the Windows setup utility configuration." -ForegroundColor Yellow
    if (Get-UserConfirmation "Did you successfully complete the Windows setup utility configuration?")
    {
      Set-StageFlag "windows-utility"
      Write-Status "Windows setup utility" -Status "Completed" -Color "Green"
      return $true
    }
    return $false
  } catch
  {
    Write-Warning "Windows setup utility encountered an error: $_"
    Write-Host "You can try running it manually by opening a new PowerShell window and running:" -ForegroundColor Yellow
    Write-Host "irm christitus.com/win | iex" -ForegroundColor Cyan
    return $false
  }
}

function Install-WindowsActivation
{
  [CmdletBinding()]
  param()
    
  Write-Status "Running Windows activation..." -Status "Starting" -Color "Yellow"
    
  if (-not (Invoke-ExternalCommand -Command 'irm https://get.activated.win | iex' -Description "Windows Activation" -UseShell))
  {
    return $false
  }
    
  Write-Host "`nPlease verify that Windows was activated correctly." -ForegroundColor Yellow
  if (Get-UserConfirmation "Was Windows activated successfully?")
  {
    Set-StageFlag "windows-activation"
    Write-Status "Windows activation" -Status "Completed" -Color "Green"
    return $true
  }
  return $false
}

function Install-PersonalRepositories
{
  [CmdletBinding()]
  param()
    
  Write-Status "Setting up personal repositories..." -Status "Starting" -Color "Yellow"
    
  # Create parent directories if needed
  $repoParentPath = "$env:USERPROFILE\repo"
  if (-not (Test-Path $repoParentPath))
  {
    New-Item -ItemType Directory -Path $repoParentPath -Force | Out-Null
    Write-Status "Created repositories directory" -Status "Done" -Color "Green"
  }
    
  # Setup Neovim config
  $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
  if (-not (Install-Repository -RepoUrl "https://github.com/PaysanCorrezien/config.nvim.git" -TargetPath $nvimConfigPath))
  {
    return $false
  }
    
  # Setup WezTerm config
  $weztermConfigPath = "$env:USERPROFILE\repo\config.wezterm"
  if (-not (Install-Repository -RepoUrl "https://github.com/PaysanCorrezien/config.wezterm" -TargetPath $weztermConfigPath))
  {
    return $false
  }
    
  # Setup and configure Chezmoi
  if (-not (Install-Chezmoi))
  {
    return $false
  }
    
  Set-StageFlag "personal-repos-setup"
  Write-Status "Personal repositories setup" -Status "Completed" -Color "Green"
  return $true
}

function Install-CLIUtilities
{
  [CmdletBinding()]
  param()
    
  # Import logging
  $logging = . "$PSScriptRoot\logging.ps1"
  $Logger = $logging.Logger
    
  $Logger::StartTask("CLI Utilities Installation")
    
  # Install Winget packages
  $cliUtils = @(
    @{Id = "rsteube.Carapace"; Description = "Command completion"; Required = $true},
    @{Id = "Slackadays.Clipboard"; Description = "Clipboard manager"; Required = $true},
    @{Id = "Gitleaks.Gitleaks"; Description = "Git secrets scanner"; Required = $true},
    @{Id = "lsd-rs.lsd"; Description = "LSDeluxe"; Required = $true},
    @{Id = "Starship.Starship"; Description = "Prompt"; Required = $true},
    @{Id = "XAMPPRocky.Tokei"; Description = "Code metrics"; Required = $true}, # Fixed package ID
    @{Id = "JohnMacFarlane.Pandoc"; Description = "Document converter"; Required = $false},
    @{Id = "Yubico.YubikeyManager"; Description = "Yubikey Manager"; Required = $false},
    @{Id = "Yubico.Authenticator"; Description = "Yubikey Authenticator"; Required = $false},
    @{Id = "sharkdp.fd"; Description = "File finder"; Required = $true},
    @{Id = "SSHFS-Win.SSHFS-Win"; Description = "SSHFS for Windows"; Required = $false},
    @{Id = "astral-sh.uv"; Description = "Python package installer"; Required = $true},
    @{Id = "sigoden.AIChat"; Description = "AI Chat client"; Required = $false},
    @{Id = "NickeManarin.ScreenToGif"; Description = "Screen recorder"; Required = $false},
    @{Id = "Gyan.FFmpeg"; Description = "Media toolkit"; Required = $true},
    @{Id = "ImageMagick.ImageMagick"; Description = "Image processing"; Required = $true}
  )
    
  $criticalFailure = $false
    
  foreach ($util in $cliUtils)
  {
    $Logger::Info("Installing $($util.Description) ($($util.Id))")
    if (-not (Install-WithWinget -PackageId $util.Id))
    {
      if ($util.Required)
      {
        $Logger::Error("Failed to install required package: $($util.Description)", $null)
        $criticalFailure = $true
        break
      } else
      {
        $Logger::Warning("Failed to install optional package: $($util.Description)")
        continue
      }
    }
  }
    
  if ($criticalFailure)
  {
    $Logger::Error("Critical failure in CLI utilities installation. Stopping process.", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  # Install Scoop packages
  $Logger::StartTask("Scoop Packages Installation")
  $scoopPackages = @(
    @{Name = "termusic"; Description = "Terminal music player"; Required = $false},
    @{Name = "ouch"; Description = "Archive utility"; Required = $true}
    # @{Name = "extras/musicbee"; Description = "Music player"; Required = $false}
  )
    
  foreach ($package in $scoopPackages)
  {
    $Logger::Info("Installing $($package.Description)")
    if (-not (Invoke-ExternalCommand -Command "scoop install $($package.Name)" -Description $package.Description))
    {
      if ($package.Required)
      {
        $Logger::Error("Failed to install required Scoop package: $($package.Description)", $null)
        $criticalFailure = $true
        break
      } else
      {
        $Logger::Warning("Failed to install optional Scoop package: $($package.Description)")
        continue
      }
    }
  }
    
  if ($criticalFailure)
  {
    $Logger::Error("Critical failure in Scoop packages installation. Stopping process.", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  # Install Rust Tools
  $Logger::StartTask("Rust Tools Installation")
  $rustTools = @(
    @{Command = "cargo install atuin"; Description = "Shell history"; Required = $true},
    @{Command = "rustup component add rust-analyzer"; Description = "Rust Analyzer"; Required = $true}
  )
    
  foreach ($tool in $rustTools)
  {
    $Logger::Info("Installing $($tool.Description)")
    if (-not (Invoke-ExternalCommand -Command $tool.Command -Description $tool.Description))
    {
      if ($tool.Required)
      {
        $Logger::Error("Failed to install required Rust tool: $($tool.Description)", $null)
        $criticalFailure = $true
        break
      } else
      {
        $Logger::Warning("Failed to install optional Rust tool: $($tool.Description)")
        continue
      }
    }
  }
    
  if ($criticalFailure)
  {
    $Logger::Error("Critical failure in Rust tools installation. Stopping process.", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  # Install Python Tools
  $Logger::StartTask("Python Tools Installation")
  $Logger::Info("Installing BusyGit")
  if (-not (Invoke-ExternalCommand -Command "python -m pip install git+https://github.com/PaysanCorrezien/BusyGit.git" -Description "BusyGit"))
  {
    $Logger::Error("Failed to install BusyGit", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  # Configure environment paths
  $Logger::StartTask("Environment Path Configuration")
  $pathsToAdd = @(
    @{
      Path = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-7.1-full_build\bin"
      Description = "FFmpeg"
      Required = $true
    },
    @{
      Path = "$env:USERPROFILE\repo\windows.config\apps\rustscan-2.3.0-x86_64-windows"
      Description = "RustScan"
      Required = $false
    },
    @{
      Path = "C:\Program Files\SSHFS-Win\bin"
      Description = "SSHFS"
      Required = $false
    },
    @{
      Path = "C:\Program Files\KeePassXC"
      Description = "KeePassXC CLI"
      Required = $true
    },
    @{
      Path = "C:\Program Files\Yubico\YubiKey Manager"
      Description = "YubiKey Manager"
      Required = $false
    }
  )

  foreach ($pathItem in $pathsToAdd)
  {
    if (Test-Path $pathItem.Path)
    {
      $Logger::Info("Adding $($pathItem.Description) to PATH")
        
      if (-not (Set-Env -Name "Path" -Value $pathItem.Path -Scope "User"))
      {
        if ($pathItem.Required)
        {
          $Logger::Error("Failed to add required path: $($pathItem.Description)", $null)
          $criticalFailure = $true
          break
        } else
        {
          $Logger::Warning("Failed to add optional path: $($pathItem.Description)")
          continue
        }
      } else
      {
        $Logger::Success("Added $($pathItem.Description) to PATH")
      }
    } else
    {
      if ($pathItem.Required)
      {
        $Logger::Error("Required path not found: $($pathItem.Path)", $null)
        $criticalFailure = $true
        break
      } else
      {
        $Logger::Warning("Optional path not found: $($pathItem.Path)")
      }
    }
  }
    
  if ($criticalFailure)
  {
    $Logger::Error("Critical failure in path configuration. Stopping process.", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  $Logger::Info("Note: Yubikey Login needs to be installed manually from:")
  $Logger::Info("https://www.yubico.com/products/yubico-login-for-windows/")
    
  Set-StageFlag "cli-utils-setup"
  $Logger::EndTask($true)
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
