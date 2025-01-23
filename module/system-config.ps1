# System Configuration Functions
Set-StrictMode -Version 3.0

function Set-FinalSystemConfigurations
{
  [CmdletBinding()]
  param()
    
  Write-Status "Applying final system configurations..." -Status "Starting" -Color "Yellow"
    
  # Configure Git SSH command
  if (-not (Invoke-ExternalCommand -Command 'git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"' -Description "Configuring Git SSH command"))
  {
    return $false
  }
  Write-Status "Git SSH configuration" -Status "Completed" -Color "Green"
    
  # Configure startup programs
  Write-Host "`nConfiguring startup programs..." -ForegroundColor Yellow
  $startupFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
  $glazeWMPath = Join-Path $startupFolder "GlazeWM.lnk"
    
  if (Test-Path $glazeWMPath)
  {
    Write-Host "Adding GlazeWM to startup programs..." -ForegroundColor Yellow
    Copy-Item $glazeWMPath "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\" -Force
    Write-Status "GlazeWM startup configuration" -Status "Completed" -Color "Green"
  } else
  {
    Write-Warning "GlazeWM shortcut not found at expected location: $glazeWMPath"
  }
    
  # Install WezTerm float version if requested
  Write-Host "`nWould you like to install the custom float version of WezTerm?" -ForegroundColor Yellow
  if (Get-UserConfirmation "Install custom WezTerm float version?")
  {
    $weztermFloatScript = Join-Path $PSScriptRoot "..\scripts\install-wezterm-float.ps1"
    if (Test-Path $weztermFloatScript)
    {
      if (-not (Invoke-ExternalCommand -Command "& '$weztermFloatScript'" -Description "Installing WezTerm float version"))
      {
        return $false
      }
      Write-Status "WezTerm float version" -Status "Installed" -Color "Green"
    } else
    {
      Write-Warning "WezTerm float installation script not found at: $weztermFloatScript"
    }
  }
    
  # Rename computer if requested
  $currentName = $env:COMPUTERNAME
  Write-Host "`nCurrent computer name: $currentName" -ForegroundColor Yellow
  Write-Host "Would you like to rename your computer? If yes, provide a new name." -ForegroundColor Yellow
  $newName = Read-Host "Enter new computer name (or press Enter to skip)"
    
  if ($newName -and ($newName -ne $currentName))
  {
    if (-not (Invoke-ExternalCommand -Command "Rename-Computer -NewName '$newName' -Force" -Description "Renaming computer"))
    {
      return $false
    }
    Write-Host "`nComputer has been renamed to '$newName'. A restart will be required for this change to take effect." -ForegroundColor Yellow
  }
    
  Set-StageFlag "final-system-config"
  Write-Status "Final system configurations" -Status "Completed" -Color "Green"
  return $true
}

function Set-OpenSSH
{
  [CmdletBinding()]
  param()
    
  # Import logging
  $logging = . "$PSScriptRoot\logging.ps1"
  $Logger = $logging.Logger
    
  $Logger::StartTask("OpenSSH Configuration")
    
  # Check if OpenSSH is already installed
  if (Test-Command "ssh")
  {
    $Logger::Info("OpenSSH is already installed")
    $Logger::EndTask($true)
    return $true
  }
    
  # Install OpenSSH Client
  if (-not (Invoke-ExternalCommand -Command 'Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0' -Description "Installing OpenSSH Client"))
  {
    $Logger::Error("Failed to install OpenSSH client", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  # Configure SSH Agent service
  if (-not (Invoke-ExternalCommand -Command 'Set-Service -Name ssh-agent -StartupType Automatic' -Description "Configuring SSH Agent"))
  {
    $Logger::Error("Failed to configure SSH agent", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  # Start SSH Agent service
  if (-not (Invoke-ExternalCommand -Command 'Start-Service ssh-agent' -Description "Starting SSH Agent"))
  {
    $Logger::Error("Failed to start SSH agent", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  $Logger::Success("OpenSSH setup completed successfully")
  $Logger::EndTask($true)
  return $true
}

function Set-DevMode
{
  [CmdletBinding()]
  param (
    [switch]$Force
  )

  begin
  {
    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin)
    {
      throw "This function requires administrative privileges. Please run PowerShell as Administrator."
    }
  }

  process
  {
    try
    {
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
      foreach ($change in $registryChanges)
      {
        # Ensure the registry path exists
        if (-not (Test-Path $change.Path))
        {
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
    } catch
    {
      Write-Error "Failed to configure development environment: $_"
      return $false
    }
  }
}

# Export functions
$exports = @{
  'Set-FinalSystemConfigurations' = ${function:Set-FinalSystemConfigurations}
  'Set-OpenSSH' = ${function:Set-OpenSSH}
  'Set-DevMode' = ${function:Set-DevMode}
}

return $exports 
