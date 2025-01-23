# tests/test_logging.ps1
using namespace System
Set-StrictMode -Version 3.0

# Import logging module
$loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "module\logging.ps1"
$logging = . $loggingPath
$Logger = $logging.Logger

# Initialize logging
$Logger::Initialize($null)

# Begin tests
$Logger::Section("Logger Test Suite")
$Logger::Info("Starting logger tests...")

# Test basic logging
$Logger::StartTask("Testing Basic Logging")
$Logger::Info("This is an info message")
$Logger::Warning("This is a warning message")
$Logger::Success("This is a success message")
$Logger::Debug("This is a debug message (only visible in debug mode)")

try
{
  throw "Test error"
} catch
{
  $Logger::Error("This is an error message with stack trace", $_)
}

$Logger::EndTask($true)

# Test progress bar
$Logger::StartTask("Testing Progress Bar")
foreach ($i in 0..100)
{
  $Logger::ShowProgress("Loading", $i)
  Start-Sleep -Milliseconds 20
}
Write-Host ""  # New line after progress
$Logger::EndTask($true)

# Test spinner
$Logger::StartTask("Testing Spinner")
Write-Host ""  # Add a line break before spinner
1..5 | ForEach-Object {
  $Logger::ShowSpinner("Processing")
  Start-Sleep -Milliseconds 500
}
# No need for extra Write-Host "", EndTask will clean up
$Logger::EndTask($true)

# Finish up
$Logger::Section("Test Summary")
$Logger::Info("All tests completed successfully")
$Logger::Info("Log file location: $($Logger::LogFile)")

# Show log contents
$Logger::Info("`nLog File Contents:")
Get-Content $Logger::LogFile | ForEach-Object {
  Write-Host "  $_" -ForegroundColor DarkGray
}
