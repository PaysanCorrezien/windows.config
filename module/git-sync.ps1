#!/usr/bin/env pwsh
Set-StrictMode -Version 3.0

# Import logging module
$logging = . "$PSScriptRoot\logging.ps1"
$Logger = $logging.Logger

function Update-ConfigurationRepositories
{
  [CmdletBinding()]
  param()
    
  $Logger::StartTask("Configuration Repository Updates")
  
  # Read configuration from JSON file
  $configPath = Join-Path $PSScriptRoot "..\gitrepos.json"
  if (-not (Test-Path $configPath)) {
    $Logger::Error("Configuration file not found: $configPath", $null)
    return $false
  }

  try {
    $configRepos = Get-Content $configPath -Raw | ConvertFrom-Json
  } catch {
    $Logger::Error("Failed to parse configuration file", $_)
    return $false
  }
    
  $success = $true
  :repo_loop foreach ($repo in $configRepos)
  {
    $repoPath = Join-Path $env:USERPROFILE $repo.path
    
    # If directory doesn't exist or is empty, clone the repository
    if (-not (Test-Path $repoPath) -or -not (Test-Path (Join-Path $repoPath ".git"))) {
      $Logger::Info("Repository not found, cloning from: $($repo.url)")
      
      # Create parent directory if it doesn't exist
      $parentDir = Split-Path $repoPath -Parent
      if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
      }
      
      # Clone the repository
      git clone $repo.url $repoPath
      if ($LASTEXITCODE -ne 0) {
        $Logger::Error("Failed to clone repository: $($repo.description)", $null)
        if ($repo.required) {
          $success = $false
        }
        continue repo_loop
      }
      $Logger::Success("Repository cloned successfully: $($repo.description)")
      continue repo_loop
    }
        
    Push-Location $repoPath
    try
    {
      $Logger::StartTask("Updating $($repo.description)")
            
      # Check for unstaged changes
      $status = git status --porcelain
      if ($status)
      {
        $Logger::Info("Unstaged changes found in $($repo.description):")
        git status --short | ForEach-Object { $Logger::Info($_) }
                
        $choices = @(
          @{Letter = "C"; Description = "Commit and push changes"}
          @{Letter = "T"; Description = "Stash changes and pull"}
          @{Letter = "I"; Description = "Skip this repository"}
        )
                
        $Logger::Info("What would you like to do with these changes?")
        $choiceString = $choices | ForEach-Object { "[$($_.Letter)] $($_.Description)" }
        $Logger::Info($choiceString -join "  ")
        $response = Read-Host "Enter choice (default is 'I')"
        $response = if ($response) { $response.ToUpper() } else { "I" }
                
        switch ($response)
        {
          "C"
          { # Commit and push
            $commitMsg = Read-Host "Enter commit message"
            $Logger::Info("Committing changes...")
            git add .
            git commit -m $commitMsg
            git push
            if ($LASTEXITCODE -ne 0)
            {
              $Logger::Error("Failed to push changes for $($repo.description)", $null)
              if ($repo.required)
              {
                $success = $false
              }
              $Logger::EndTask($false)
              Pop-Location
              continue repo_loop
            }
            $Logger::Success("Changes committed and pushed")
          }
          "T"
          { # Stash
            $Logger::Info("Stashing changes...")
            git stash
            if ($LASTEXITCODE -ne 0)
            {
              $Logger::Error("Failed to stash changes for $($repo.description)", $null)
              if ($repo.required)
              {
                $success = $false
              }
              $Logger::EndTask($false)
              Pop-Location
              continue repo_loop
            }
            $Logger::Success("Changes stashed")
          }
          "I"
          { # Skip this repository entirely
            $Logger::Info("Skipping $($repo.description)")
            $Logger::EndTask($true)
            Pop-Location
            continue repo_loop
          }
        }
      }
            
      # Proceed with update
      $Logger::Info("Fetching updates...")
      git fetch origin
      if ($LASTEXITCODE -ne 0)
      {
        $Logger::Error("Failed to fetch updates for $($repo.description)", $null)
        if ($repo.required)
        {
          $success = $false
        }
        $Logger::EndTask($false)
        Pop-Location
        continue repo_loop
      }
            
      # Get current branch
      $currentBranch = git rev-parse --abbrev-ref HEAD
      if ($LASTEXITCODE -ne 0)
      {
        $Logger::Error("Failed to get current branch for $($repo.description)", $null)
        if ($repo.required)
        {
          $success = $false
        }
        $Logger::EndTask($false)
        Pop-Location
        continue repo_loop
      }
            
      # Pull changes
      $Logger::Info("Pulling updates...")
      git pull origin $currentBranch
      if ($LASTEXITCODE -ne 0)
      {
        $Logger::Error("Failed to pull updates for $($repo.description)", $null)
        if ($repo.required)
        {
          $success = $false
        }
        $Logger::EndTask($false)
        Pop-Location
        continue repo_loop
      }
            
      $Logger::Success("$($repo.description) updated successfully")
      $Logger::EndTask($true)
    } catch
    {
      $Logger::Error("Failed to update $($repo.description)", $_)
      if ($repo.required)
      {
        $success = $false
      }
      $Logger::EndTask($false)
    } finally
    {
      Pop-Location
    }
  }
    
  if ($success)
  {
    $Logger::Success("All required repository updates completed successfully")
  } else
  {
    $Logger::Error("Some required repository updates failed", $null)
  }
    
  $Logger::EndTask($success)
  return $success
}

# Export functions
$exports = @{
  'Update-ConfigurationRepositories' = ${function:Update-ConfigurationRepositories}
}

return $exports 