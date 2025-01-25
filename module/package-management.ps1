# Package Management Functions
Set-StrictMode -Version 3.0

function Install-Chezmoi
{
  [CmdletBinding()]
  param()
    
  $Logger::StartTask("Chezmoi Installation")
    
  # Install Chezmoi if not present
  if (-not (Test-Command "chezmoi"))
  {
    $Logger::Info("Installing Chezmoi package...")
    if (-not (Install-WithWinget -PackageId "twpayne.chezmoi"))
    {
      $Logger::Error("Failed to install Chezmoi package", $null)
      $Logger::EndTask($false)
      return $false
    }
        
    # Reload PATH to ensure chezmoi is available
    Reload-Path
  }
    
  $Logger::Info("Setting up Chezmoi dotfiles...")
    
  # Set safe directory
  if (-not (Invoke-ExternalCommand -Command 'git config --global --add safe.directory C:/Users/admin/.local/share/chezmoi' `
        -Description "Setting safe directory for chezmoi"))
  {
    $Logger::Error("Failed to set safe directory for chezmoi", $null)
    $Logger::EndTask($false)
    return $false
  }

  # Check if chezmoi is already initialized
  $chezmoiDir = "$env:USERPROFILE\.local\share\chezmoi"
  $isInitialized = Test-Path $chezmoiDir

  if ($isInitialized)
  {
    $Logger::Info("Chezmoi is already initialized. Checking for changes...")
    
    # Update source state
    if (-not (Invoke-ExternalCommand -Command "chezmoi update" -Description "Updating chezmoi source state"))
    {
      $Logger::Error("Failed to update chezmoi source state", $null)
      $Logger::EndTask($false)
      return $false
    }
  } else
  {
    $Logger::Info("Initializing Chezmoi...")
    
    # Initialize without applying
    if (-not (Invoke-ExternalCommand -Command "chezmoi init https://github.com/PaysanCorrezien/chezmoi-win" `
          -Description "Initializing Chezmoi configuration"))
    {
      $Logger::Error("Failed to initialize chezmoi", $null)
      $Logger::EndTask($false)
      return $false
    }
  }

  # Show changes that would be made
  $Logger::Info("Reviewing changes to be applied...")
  if (-not (Invoke-ExternalCommand -Command "chezmoi diff" -Description "Showing pending changes"))
  {
    $Logger::Error("Failed to show pending changes", $null)
    $Logger::EndTask($false)
    return $false
  }

  # Ask for confirmation before applying
  if (-not (Get-UserConfirmation "Would you like to apply these changes?"))
  {
    $Logger::Info("Skipping chezmoi apply. You can apply changes later with 'chezmoi apply'")
    $Logger::EndTask($true)
    return $true
  }

  # Apply changes
  if (-not (Invoke-ExternalCommand -Command "chezmoi apply -v" -Description "Applying Chezmoi configuration"))
  {
    $Logger::Error("Failed to apply chezmoi configuration", $null)
    $Logger::EndTask($false)
    return $false
  }
    
  $Logger::Success("Chezmoi configuration has been applied successfully")
  $Logger::Info("You can manage your dotfiles with the following commands:")
  $Logger::Info("- chezmoi diff    : Show pending changes")
  $Logger::Info("- chezmoi add     : Add a file to chezmoi")
  $Logger::Info("- chezmoi edit    : Edit a managed file")
  $Logger::Info("- chezmoi apply   : Apply pending changes")
  $Logger::Info("- chezmoi update  : Pull and apply latest changes")
    
  $Logger::EndTask($true)
  return $true
}

function Install-Repository
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,
    [Parameter(Mandatory=$true)]
    [string]$TargetPath,
    [string]$Description = ""
  )
    
  if (-not $Description)
  {
    $Description = Split-Path $TargetPath -Leaf
  }
    
  if (-not (Test-Path $TargetPath))
  {
    if (-not (Invoke-ExternalCommand -Command "git clone $RepoUrl $TargetPath" `
          -Description "Cloning $Description"))
    {
      return $false
    }
    Write-Status "$Description" -Status "Cloned" -Color "Green"
  } else
  {
    Write-Status "$Description" -Status "Already exists" -Color "Green"
  }
    
  return $true
}

function Install-ApplicationPackages
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [hashtable[]]$Packages,
    [string]$Description = "packages"
  )
    
  Write-Status "Installing $Description..." -Status "Starting" -Color "Yellow"
    
  foreach ($package in $Packages)
  {
    if (-not (Install-WithWinget -PackageId $package.Id))
    {
      Write-Warning "Failed to install $($package.Description)"
      return $false
    }
  }
    
  Write-Status "$Description installation" -Status "Completed" -Color "Green"
  return $true
}

# Export functions
$exports = @{
  'Install-Chezmoi' = ${function:Install-Chezmoi}
  'Install-Repository' = ${function:Install-Repository}
  'Install-ApplicationPackages' = ${function:Install-ApplicationPackages}
}

return $exports 
