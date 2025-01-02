#!/usr/bin/env pwsh
#Requires -RunAsAdministrator
Set-StrictMode -Version 3.0

function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
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
    
    # Run the installation script
    Write-Host "Running installation script..." -ForegroundColor Yellow
    & .\install.ps1
    
    if (-not $?) {
        Write-Error "Installation failed"
        exit 1
    }
    
    Write-Host "Installation completed successfully!" -ForegroundColor Green
}

# Main execution
Write-Host "Starting Windows configuration setup..." -ForegroundColor Cyan

# Install Git if needed
Install-GitIfNeeded

# Clone repository
$repoPath = Clone-Repository

# Start installation
Start-Installation -RepoPath $repoPath 