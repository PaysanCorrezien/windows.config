#Requires -RunAsAdministrator
Set-StrictMode -Version 3.0

function Get-Env
{
  param (
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [Parameter(Mandatory=$false)]
    [ValidateSet('User', 'Machine')]
    [string]$Scope = 'User'
  )

  try
  {
    return [System.Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::$Scope)
  } catch
  {
    Write-Error "Failed to get environment variable $Name`: $_"
    return $null
  }
}

function Set-Env
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [Parameter(Mandatory=$true)]
    [string]$Value,
    [Parameter(Mandatory=$false)]
    [ValidateSet('User', 'Machine')]
    [string]$Scope = 'User'
  )

  try
  {
    Write-Verbose "Setting $Name in $Scope scope"
    $target = [System.EnvironmentVariableTarget]::$Scope
        
    # Special handling for PATH variable
    if ($Name -eq 'Path')
    {
      # Get current PATH
      $currentValue = [System.Environment]::GetEnvironmentVariable('Path', $target)
            
      # Split paths into array and remove empty entries
      $currentPaths = @()
      if ($currentValue)
      {
        $currentPaths = $currentValue -split ';' | Where-Object { $_ -and (Test-Path $_) }
      }
      $newPath = $Value.TrimEnd(';')
            
      # Check if path is already in the PATH
      if ($currentPaths -notcontains $newPath)
      {
        # Add new path to the beginning and remove any duplicates
        $allPaths = @($currentPaths) + @($newPath) | Select-Object -Unique
        $finalValue = ($allPaths | Where-Object { $_ }) -join ';'
                
        # Set the new PATH
        [System.Environment]::SetEnvironmentVariable('Path', $finalValue, $target)
                
        # Update current session's PATH
        $env:Path = $finalValue
                
        Write-Verbose "Successfully added to PATH: $newPath"
        return $true
      } else
      {
        Write-Verbose "Path already exists in PATH: $newPath"
        return $true
      }
    } else
    {
      # For non-PATH variables, just set directly
      [System.Environment]::SetEnvironmentVariable($Name, $Value, $target)
      Write-Verbose "Successfully set $Name"
      return $true
    }
  } catch
  {
    Write-Error "Failed to set environment variable: $_"
    return $false
  }
}


function Reload-Path
{
  [CmdletBinding()]
  param()

  try
  {
    Write-Verbose "Reloading PATH environment variable"

    # Get both System and User PATH
    $SystemPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $UserPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')

    # Combine them
    $NewPath = $SystemPath
    if ($UserPath)
    {
      $NewPath = $NewPath + ';' + $UserPath
    }

    # Update current session
    $env:PATH = $NewPath

    # Broadcast WM_SETTINGCHANGE message to notify other applications
    if (-not ('Win32.NativeMethods' -as [Type]))
    {
      Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
                [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                public static extern IntPtr SendMessageTimeout(
                    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
                    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }

    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x1a
    $result = [UIntPtr]::Zero
        
    $ret = [Win32.NativeMethods]::SendMessageTimeout(
      $HWND_BROADCAST,
      $WM_SETTINGCHANGE,
      [UIntPtr]::Zero,
      'Environment',
      2,
      5000,
      [ref]$result
    )

    Write-Host "PATH has been reloaded for current session"
    Write-Host "New applications in PATH can now be used without restarting the shell"
    return $true
  } catch
  {
    Write-Error "Failed to reload PATH: $_"
    return $false
  }
}

function Write-Status
{
  param(
    [string]$Message,
    [string]$Status,
    [string]$Color = "Green"
  )
  Write-Host "$Message".PadRight(50) -NoNewline
  Write-Host "[$Status]" -ForegroundColor $Color
}

function Write-Log
{
  param([string]$Message)
  Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

function Set-RegistryValue
{
  param (
    [string]$Path,
    [string]$Name,
    $Value,
    [string]$Type = "DWORD"
  )
    
  try
  {
    if (-not (Test-Path $Path))
    {
      New-Item -Path $Path -Force | Out-Null
      Write-Log "Created new registry path: $Path"
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value
    Write-Log "Successfully set registry value: $Path\$Name"
  } catch
  {
    Write-Log "Error setting registry value: $_"
    throw
  }
}

function Restart-Explorer
{
  try
  {
    Write-Log "Restarting Explorer to apply changes..."
    Get-Process "explorer" | Stop-Process -Force
    Start-Sleep -Seconds 2
    Start-Process "explorer"
    Write-Log "Explorer restarted successfully"
  } catch
  {
    Write-Log "Error restarting Explorer: $_"
    throw
  }
}

function Set-StageFlag
{
  param (
    [Parameter(Mandatory=$true)]
    [string]$StageName
  )
    
  try
  {
    $flagsDir = Join-Path $PSScriptRoot "..\flags"
    if (-not (Test-Path $flagsDir))
    {
      New-Item -ItemType Directory -Path $flagsDir -Force | Out-Null
    }
        
    $flagPath = Join-Path $flagsDir "$StageName.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $timestamp | Set-Content $flagPath -Force
    Write-Verbose "Created flag for stage: $StageName"
    return $true
  } catch
  {
    Write-Error "Failed to create flag file for stage $StageName`: $_"
    return $false
  }
}

function Test-StageFlag
{
  param (
    [Parameter(Mandatory=$true)]
    [string]$StageName
  )
    
  $flagPath = Join-Path $PSScriptRoot "..\flags\$StageName.txt"
  return Test-Path $flagPath
}

function Invoke-ExternalCommand
{
  param (
    [Parameter(Mandatory=$true)]
    [string]$Command,
    [string]$Description,
    [switch]$UseShell
  )
    
  # Import logging
  $logging = . "$PSScriptRoot\logging.ps1"
  $Logger = $logging.Logger
    
  try
  {
    $Logger::StartTask($Description)
        
    if ($UseShell)
    {
      $scriptBlock = [Scriptblock]::Create($Command)
      $output = & $scriptBlock 2>&1
    } else
    {
      # Capture both stdout and stderr
      $output = Invoke-Expression -Command $Command 2>&1
    }
        
    # Convert output to string if it's not already
    $outputString = $output | Out-String
        
    # Check for error conditions in various ways:
    $hasError = $false
        
    # 1. Check exit code if available
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0)
    {
      $hasError = $true
    }
        
    # 2. Check if output contains error indicators
    $errorIndicators = @(
      'ERROR:', 
      'Error:', 
      'FATAL:', 
      'Fatal:', 
      'Failed:', 
      'Failure:', 
      'dependency conflicts',
      'incompatible',
      'not found',
      'No such file'
    )
        
    foreach ($indicator in $errorIndicators)
    {
      if ($outputString -match $indicator)
      {
        $hasError = $true
        break
      }
    }
        
    # If we detected an error
    if ($hasError)
    {
      $Logger::Error("Command failed: $Description", $null)
      $Logger::Debug("Command output:`n$outputString")
      $Logger::EndTask($false)
      return $false
    }
        
    # Log output in debug mode
    $Logger::Debug("Command output:`n$outputString")
    $Logger::EndTask($true)
    return $true
  } catch
  {
    $Logger::Error("Exception in command: $Description", $_)
    $Logger::EndTask($false)
    return $false
  }
}

function Test-Command($cmdname)
{
  return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

function Install-WithWinget
{
  param (
    [Parameter(Mandatory = $true)]
    [string]$PackageId,
    [string]$Source = "winget",
    [string[]]$AdditionalArguments = @(),
    [switch]$NoCheckAlreadyInstalled
  )

  # Import logging
  $logging = . "$PSScriptRoot\logging.ps1"
  $Logger = $logging.Logger

  try
  {
    # Check if already installed
    if (-not $NoCheckAlreadyInstalled)
    {
      $checkOutput = winget list --id $PackageId 2>&1
      if ($checkOutput -match $PackageId)
      {
        $Logger::Info("$PackageId is already installed")
        return $true
      }
    }

    # Build installation command
    $baseArgs = @(
      "install",
      "--exact",
      "--id",
      $PackageId,
      "--accept-source-agreements",
      "--accept-package-agreements"
    )
        
    if ($Source -ne "winget")
    {
      $baseArgs += @("--source", $Source)
    }
        
    $baseArgs += $AdditionalArguments
        
    # Verify package exists before attempting install
    $searchOutput = winget search --id $PackageId --exact 2>&1
    if ($LASTEXITCODE -ne 0 -or -not ($searchOutput -match $PackageId))
    {
      $Logger::Error("Package $PackageId not found in winget repository", $null)
      return $false
    }
        
    # Attempt installation
    $installOutput = & winget $baseArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0)
    {
      $errorDetail = $installOutput | Out-String
      $manualCommand = "winget install --exact --id $PackageId $(if($Source -ne 'winget'){`"--source $Source`"})"
            
      $Logger::Error("Failed to install $PackageId (Exit code: $exitCode)", $null)
      $Logger::Info("Manual installation command:")
      $Logger::Info($manualCommand)
            
      return $false
    }

    $Logger::Success("$PackageId installation completed")
    return $true
  } catch
  {
    $Logger::Error("Exception during $PackageId installation: $($_.Exception.Message)", $_)
    return $false
  }
}

function Update-GitRepository
{
  param (
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,
    [string]$Description = "repository"
  )
    
  try
  {
    if (-not (Test-Path $RepoPath))
    {
      Write-Warning "$Description not found at: $RepoPath"
      return $false
    }
        
    Push-Location $RepoPath
    Write-Host "Updating $Description..." -ForegroundColor Yellow
        
    # Fetch latest changes
    git fetch origin
    if ($LASTEXITCODE -ne 0)
    {
      throw "Failed to fetch updates"
    }
        
    # Get current branch
    $currentBranch = git rev-parse --abbrev-ref HEAD
    if ($LASTEXITCODE -ne 0)
    {
      throw "Failed to get current branch"
    }
        
    # Pull changes
    git pull origin $currentBranch
    if ($LASTEXITCODE -ne 0)
    {
      throw "Failed to pull updates"
    }
        
    Write-Host "$Description updated successfully" -ForegroundColor Green
    return $true
  } catch
  {
    Write-Warning "Failed to update $Description`: $_"
    return $false
  } finally
  {
    Pop-Location
  }
}

function Get-UserConfirmation
{
  param (
    [string]$Message
  )
  $title = "Confirmation Required"
  $choices = @(
    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "The action was successful")
    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "The action failed or needs to be retried")
  )
  $decision = $Host.UI.PromptForChoice($title, $Message, $choices, 0)
  return $decision -eq 0
}

function Handle-Error
{
  param (
    [string]$ErrorMessage,
    [string]$Stage,
    [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
  )
  Write-Error $ErrorMessage
  Write-Host "`nAn error occurred during $Stage." -ForegroundColor Red
    
  if ($ErrorRecord)
  {
    Write-Host "`nDetailed Error Information:" -ForegroundColor Yellow
    Write-Host "Exception Type: $($ErrorRecord.Exception.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "Exception Message: $($ErrorRecord.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Error Category: $($ErrorRecord.CategoryInfo.Category)" -ForegroundColor Yellow
    if ($ErrorRecord.ScriptStackTrace)
    {
      Write-Host "`nStack Trace:" -ForegroundColor Yellow
      Write-Host $ErrorRecord.ScriptStackTrace -ForegroundColor Gray
    }
  }

  Write-Host "`nYou can investigate the error before deciding to continue or exit." -ForegroundColor Yellow
  if (-not (Get-UserConfirmation "Would you like to continue with the rest of the installation?"))
  {
    Write-Host "Script stopped. You can run it again after fixing the issue." -ForegroundColor Yellow
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return $false
  }
  Write-Host "Continuing with the next step..." -ForegroundColor Green
  return $true
}

function Pause-Script
{
  Write-Host "Press any key to continue..." -ForegroundColor Yellow
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Exit-Script
{
  Write-Host "Press any key to exit..." -ForegroundColor Yellow
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  return
}

# Export functions
$exports = @{
  'Write-Status' = ${function:Write-Status}
  'Write-Log' = ${function:Write-Log}
  'Set-StageFlag' = ${function:Set-StageFlag}
  'Test-StageFlag' = ${function:Test-StageFlag}
  'Invoke-ExternalCommand' = ${function:Invoke-ExternalCommand}
  'Get-Env' = ${function:Get-Env}
  'Set-Env' = ${function:Set-Env}
  'Reload-Path' = ${function:Reload-Path}
  'Test-Command' = ${function:Test-Command}
  'Install-WithWinget' = ${function:Install-WithWinget}
  'Update-GitRepository' = ${function:Update-GitRepository}
  'Get-UserConfirmation' = ${function:Get-UserConfirmation}
  'Handle-Error' = ${function:Handle-Error}
  'Pause-Script' = ${function:Pause-Script}
  'Exit-Script' = ${function:Exit-Script}
}

return $exports

