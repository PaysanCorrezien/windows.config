#!/usr/bin/env pwsh
Set-StrictMode -Version 3.0

function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminPrivileges {
    if (-not (Test-AdminPrivileges)) {
        Write-Host "Requesting administrative privileges..." -ForegroundColor Yellow
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Wait
        exit
    }
}

function Install-GitIfNeeded {
    if (-not (Test-Command "git")) {
        Write-Host "Git not found. Installing Git..." -ForegroundColor Yellow
        winget install --id Git.Git -e --source winget
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        if (-not (Test-Command "git")) {
            Write-Error "Failed to install Git. Please install it manually from https://git-scm.com/"
            exit 1
        }
    }
    Write-Host "Git is installed" -ForegroundColor Green
}

function Clone-Repository {
    $repoPath = "$env:USERPROFILE\repo\windows.config"
    
    if (Test-Path $repoPath) {
        Write-Host "Repository directory already exists at $repoPath" -ForegroundColor Yellow
        Write-Host "Updating repository with latest changes..." -ForegroundColor Yellow
        
        # Store current location
        $currentLocation = Get-Location
        
        # Change to repo directory and update
        Set-Location $repoPath
        git pull | Out-Host
        
        # Check git pull result
        if (-not $?) {
            Set-Location $currentLocation
            Write-Error "Failed to update repository"
            exit 1
        }
        
        # Restore location
        Set-Location $currentLocation
        
        Write-Host "Repository updated successfully" -ForegroundColor Green
        return $repoPath
    }
    
    # Create repo directory if it doesn't exist
    $repoParentPath = "$env:USERPROFILE\repo"
    if (-not (Test-Path $repoParentPath)) {
        New-Item -ItemType Directory -Path $repoParentPath -Force | Out-Null
    }
    
    Write-Host "Cloning repository to $repoPath..." -ForegroundColor Yellow
    git clone https://github.com/paysancorrezien/windows.config.git $repoPath
    
    if (-not $?) {
        Write-Error "Failed to clone repository"
        exit 1
    }
    
    Write-Host "Repository cloned successfully" -ForegroundColor Green
    return $repoPath
}

function Start-Installation {
    param (
        [string]$RepoPath
    )
    
    Set-Location $RepoPath
    
    # Run the installation script with elevated privileges
    Write-Host "Running installation script..." -ForegroundColor Yellow
    if (-not (Test-AdminPrivileges)) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$RepoPath\install.ps1`"" -Wait
    } else {
        & .\install.ps1
    }
    
    if (-not $?) {
        Write-Error "Installation failed"
        exit 1
    }
    
    Write-Host "Installation completed successfully!" -ForegroundColor Green
}

# Main execution
Write-Host "Starting Windows configuration setup..." -ForegroundColor Cyan

# Request admin privileges if needed for Git installation
Request-AdminPrivileges

# Install Git if needed
Install-GitIfNeeded

# Clone repository
$repoPath = Clone-Repository

# Start installation
Start-Installation -RepoPath $repoPath 