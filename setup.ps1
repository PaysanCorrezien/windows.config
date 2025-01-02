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
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) {
            # If running from irm, save the script first
            $tempScript = Join-Path $env:TEMP "windows-config-setup.ps1"
            $scriptContent = Invoke-RestMethod "https://raw.githubusercontent.com/paysancorrezien/windows.config/master/setup.ps1"
            Set-Content -Path $tempScript -Value $scriptContent
            $scriptPath = $tempScript
        }
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait
        if ($tempScript) {
            Remove-Item $tempScript -ErrorAction SilentlyContinue
        }
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
        
        Push-Location $repoPath
        try {
            # Capture git output but don't let it interfere with the pipeline
            $gitOutput = git pull 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Git pull failed: $gitOutput"
            }
            Write-Host $gitOutput
            Write-Host "Repository updated successfully" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to update repository: $_"
            exit 1
        }
        finally {
            Pop-Location
        }
        
        return $repoPath
    }
    
    # Create repo directory if it doesn't exist
    $repoParentPath = "$env:USERPROFILE\repo"
    if (-not (Test-Path $repoParentPath)) {
        New-Item -ItemType Directory -Path $repoParentPath -Force | Out-Null
    }
    
    Write-Host "Cloning repository to $repoPath..." -ForegroundColor Yellow
    
    # Capture git clone output
    $gitOutput = git clone https://github.com/paysancorrezien/windows.config.git $repoPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone repository: $gitOutput"
        exit 1
    }
    Write-Host $gitOutput
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