# logging.ps1
Set-StrictMode -Version 3.0

class LogLevel
{
  static [string] $Debug = 'Debug'
  static [string] $Info = 'Info'
  static [string] $Warning = 'Warning'
  static [string] $Error = 'Error'
  static [string] $Success = 'Success'
}

class Logger
{
  static [string] $LogFile
  static [bool] $DebugMode = $false
  static [string] $LastStatus = ""
  static [int] $ProgressWidth = 50
  static [System.ConsoleColor] $InfoColor = [System.ConsoleColor]::Cyan
  static [System.ConsoleColor] $SuccessColor = [System.ConsoleColor]::Green
  static [System.ConsoleColor] $WarningColor = [System.ConsoleColor]::Yellow
  static [System.ConsoleColor] $ErrorColor = [System.ConsoleColor]::Red
  static [System.ConsoleColor] $DebugColor = [System.ConsoleColor]::Gray

  static Logger()
  {
    # Initialize LogFile in static constructor
    [Logger]::LogFile = Join-Path $env:TEMP "windows-setup.log"
  }

  static [void] Initialize([string]$CustomLogPath)
  {
    if ($CustomLogPath)
    {
      [Logger]::LogFile = $CustomLogPath
    }

    # Create log directory if it doesn't exist
    $logDir = Split-Path -Parent ([Logger]::LogFile)
    if (-not (Test-Path $logDir))
    {
      New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Create or clear log file
    "" | Set-Content ([Logger]::LogFile)
        
    # Try to set console width if running in interactive mode
    try
    {
      if (-not [Environment]::UserInteractive)
      { return 
      }
            
      # Check if we're in a regular console with access to RawUI
      if ($global:Host -and 
        $global:Host.UI -and 
        $global:Host.UI.RawUI -and 
        $global:Host.UI.RawUI.GetType().Name -eq "InternalHostRawUI")
      {
                
        $windowSize = $global:Host.UI.RawUI.WindowSize
        if ($null -ne $windowSize -and $windowSize.Width -lt 80)
        {
          $windowSize.Width = 80
          $global:Host.UI.RawUI.WindowSize = $windowSize
        }
      }
    } catch
    {
      [Logger]::WriteToFile([LogLevel]::Debug, "Window size adjustment skipped: $_")
    }
  }

  static [void] WriteToFile([string]$Level, [string]$Message)
  {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Add-Content -Path ([Logger]::LogFile) -Value $logMessage -ErrorAction SilentlyContinue
  }

  static [void] Debug([string]$Message)
  {
    if ([Logger]::DebugMode)
    {
      Write-Host "🔍 $Message" -ForegroundColor ([Logger]::DebugColor)
    }
    [Logger]::WriteToFile([LogLevel]::Debug, $Message)
  }

  static [void] Info([string]$Message)
  {
    [Logger]::Info($Message, $false)
  }

  static [void] Info([string]$Message, [bool]$NoNewLine)
  {
    if (-not $NoNewLine)
    {
      Write-Host "ℹ️ $Message" -ForegroundColor ([Logger]::InfoColor)
    } else
    {
      Write-Host "ℹ️ $Message" -ForegroundColor ([Logger]::InfoColor) -NoNewline
    }
    [Logger]::WriteToFile([LogLevel]::Info, $Message)
  }

  static [void] Warning([string]$Message)
  {
    Write-Host "⚠️ $Message" -ForegroundColor ([Logger]::WarningColor)
    [Logger]::WriteToFile([LogLevel]::Warning, $Message)
  }

  static [void] Error([string]$Message, [System.Management.Automation.ErrorRecord]$ErrorRecord)
  {
    Write-Host "❌ $Message" -ForegroundColor ([Logger]::ErrorColor)
    [Logger]::WriteToFile([LogLevel]::Error, $Message)
        
    if ($ErrorRecord)
    {
      $errorDetails = @(
        "Exception Details:",
        "Type: $($ErrorRecord.Exception.GetType().FullName)",
        "Message: $($ErrorRecord.Exception.Message)",
        "Script: $($ErrorRecord.InvocationInfo.ScriptName)",
        "Line Number: $($ErrorRecord.InvocationInfo.ScriptLineNumber)",
        "Stack Trace: $($ErrorRecord.ScriptStackTrace)"
      )
            
      foreach ($detail in $errorDetails)
      {
        [Logger]::WriteToFile([LogLevel]::Error, $detail)
        if ([Logger]::DebugMode)
        {
          Write-Host "  $detail" -ForegroundColor ([Logger]::ErrorColor)
        }
      }
    }
  }

  static [void] Success([string]$Message)
  {
    Write-Host "✓ $Message" -ForegroundColor ([Logger]::SuccessColor)
    [Logger]::WriteToFile([LogLevel]::Success, $Message)
  }

  static [void] StartTask([string]$TaskName)
  {
    [Logger]::LastStatus = $TaskName
    [Logger]::Info("`n=== $TaskName ===`n", $true)  # Add newline after title
    [Logger]::WriteToFile([LogLevel]::Info, "Started: $TaskName")
  }

  static [void] ShowSpinner([string]$Message)
  {
    $spinChars = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    $frame = $spinChars[[math]::Floor((Get-Date).Millisecond / 100) % $spinChars.Length]
    $spinnerText = "$frame $Message"
    # Clear the entire line before writing
    Write-Host "`r$((" " * [Console]::WindowWidth))" -NoNewline
    Write-Host "`r$spinnerText" -NoNewline
    [Logger]::WriteToFile([LogLevel]::Info, "Processing: $Message")
  }

  static [void] EndTask([bool]$Successful)
  {
    # Clear the entire line first
    Write-Host "`r$((" " * [Console]::WindowWidth))" -NoNewline
    
    # Now write the status on a clean line
    $status = if ($Successful)
    { "✓ Done" 
    } else
    { "✗ Failed" 
    }
    $color = if ($Successful)
    { [Logger]::SuccessColor 
    } else
    { [Logger]::ErrorColor 
    }
    Write-Host "`r$status" -ForegroundColor $color
    
    $result = if ($Successful)
    { "Completed" 
    } else
    { "Failed" 
    }
    [Logger]::WriteToFile([LogLevel]::Info, "$([Logger]::LastStatus) - $result")
  }

  static [void] ShowProgress([string]$Message, [int]$PercentComplete)
  {
    $width = [Logger]::ProgressWidth
    $completed = [math]::Floor($width * ($PercentComplete / 100))
    $remaining = $width - $completed
        
    $progressBar = "[" + ("=" * $completed) + (" " * $remaining) + "]"
    $progressText = "$Message $progressBar $PercentComplete%"
        
    Write-Host "`r$progressText" -NoNewline
    [Logger]::WriteToFile([LogLevel]::Info, "$Message - $PercentComplete%")
  }


  static [void] Section([string]$Title)
  {
    $padding = "=" * [math]::Max(0, (([Logger]::ProgressWidth - $Title.Length) / 2))
    $header = "`n$padding $Title $padding`n"
    Write-Host $header -ForegroundColor ([Logger]::InfoColor)
    [Logger]::WriteToFile([LogLevel]::Info, $header)
  }
}

# Export the classes
@{
  'Logger' = [Logger]
  'LogLevel' = [LogLevel]
}
