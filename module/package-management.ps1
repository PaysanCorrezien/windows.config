# Package Management Functions
Set-StrictMode -Version 3.0

function Install-Chezmoi {
    [CmdletBinding()]
    param()
    
    Write-Status "Installing Chezmoi..." -Status "Starting" -Color "Yellow"
    
    # Install Chezmoi if not present
    if (-not (Test-Command "chezmoi")) {
        if (-not (Install-WithWinget -PackageId "twpayne.chezmoi")) {
            return $false
        }
        
        # Reload PATH to ensure chezmoi is available
        Reload-Path
    }
    
    Write-Host "`nInitializing Chezmoi with dotfiles:" -ForegroundColor Yellow
    
    # Set safe directory
    if (-not (Invoke-ExternalCommand -Command 'git config --global --add safe.directory C:/Users/admin/.local/share/chezmoi' `
            -Description "Setting safe directory for chezmoi")) {
        return $false
    }
    
    # Clear existing chezmoi directory if it exists
    $chezmoiDir = "C:/Users/admin/.local/share/chezmoi"
    if (Test-Path $chezmoiDir) {
        if (-not (Invoke-ExternalCommand -Command "Remove-Item -Recurse -Force $chezmoiDir" `
                -Description "Clearing existing chezmoi directory")) {
            return $false
        }
    }
    
    # Initialize and apply chezmoi
    if (-not (Invoke-ExternalCommand -Command "chezmoi init https://github.com/PaysanCorrezien/chezmoi-win --apply" `
            -Description "Initializing and applying Chezmoi configuration")) {
        return $false
    }
    
    Write-Host "`nChezmoi configuration has been applied." -ForegroundColor Green
    
    Write-Host "`nPlease review Chezmoi changes:" -ForegroundColor Yellow
    Write-Host "1. Review proposed changes with: chezmoi diff" -ForegroundColor Yellow
    Write-Host "2. Apply changes with: chezmoi apply -v" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you successfully review and apply Chezmoi changes?")) {
        return $false
    }
    
    return $true
}

function Install-Repository {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$RepoUrl,
        [Parameter(Mandatory=$true)]
        [string]$TargetPath,
        [string]$Description = ""
    )
    
    if (-not $Description) {
        $Description = Split-Path $TargetPath -Leaf
    }
    
    if (-not (Test-Path $TargetPath)) {
        if (-not (Invoke-ExternalCommand -Command "git clone $RepoUrl $TargetPath" `
                -Description "Cloning $Description")) {
            return $false
        }
        Write-Status "$Description" -Status "Cloned" -Color "Green"
    } else {
        Write-Status "$Description" -Status "Already exists" -Color "Green"
    }
    
    return $true
}

function Install-ApplicationPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable[]]$Packages,
        [string]$Description = "packages"
    )
    
    Write-Status "Installing $Description..." -Status "Starting" -Color "Yellow"
    
    foreach ($package in $Packages) {
        if (-not (Install-WithWinget -PackageId $package.Id)) {
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