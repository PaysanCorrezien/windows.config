# Work Setup Functions
Set-StrictMode -Version 3.0

function Install-WorkTools {
    [CmdletBinding()]
    param()
    
    Write-Status "Setting up work tools..." -Status "Starting" -Color "Yellow"
    
    # Install FortiClient VPN
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Visit https://www.fortinet.com/support/product-downloads" -ForegroundColor Yellow
    Write-Host "2. Download FortiClient VPN" -ForegroundColor Yellow
    Write-Host "3. Install FortiClient VPN" -ForegroundColor Yellow
    Write-Host "4. Disable 'Launch on Startup' in settings" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you install and configure FortiClient VPN?")) {
        return $false
    }
    
    # Install Avaya Workplace
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Download Avaya Workplace" -ForegroundColor Yellow
    Write-Host "2. Install Avaya Workplace" -ForegroundColor Yellow
    Write-Host "3. Disable 'Launch on Startup' in settings" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you install and configure Avaya Workplace?")) {
        return $false
    }
    
    return $true
}

function Install-UniGetUI {
    [CmdletBinding()]
    param()
    
    Write-Status "Installing UniGet UI..." -Status "Starting" -Color "Yellow"
    
    try {
        # First check if already installed
        $checkOutput = winget list --id MartiCliment.UniGetUI 2>&1
        if ($checkOutput -match "MartiCliment.UniGetUI") {
            Write-Host "UniGet UI is already installed" -ForegroundColor Green
            return $true
        }
        
        # Install UniGet UI
        if (-not (Install-WithWinget -PackageId "MartiCliment.UniGetUI" -Source "winget")) {
            return $false
        }

        Write-Host "`nPlease:" -ForegroundColor Yellow
        Write-Host "1. Launch UniGet UI" -ForegroundColor Yellow
        Write-Host "2. Accept dependencies" -ForegroundColor Yellow
        Write-Host "3. Load your previous settings" -ForegroundColor Yellow
        Write-Host "4. Reinstall your previous working state" -ForegroundColor Yellow
        
        if (-not (Get-UserConfirmation "Did you successfully set up UniGet UI and restore your settings?")) {
            return $false
        }
        
        return $true
    }
    catch {
        Write-Warning "Failed to install UniGet UI: $_"
        return $false
    }
}

function Install-ChatGPT {
    [CmdletBinding()]
    param()
    
    Write-Status "Setting up ChatGPT..." -Status "Starting" -Color "Yellow"
    
    Write-Host "`nPlease setup ChatGPT:" -ForegroundColor Yellow
    Write-Host "1. Download ChatGPT from the Microsoft Store" -ForegroundColor Yellow
    Write-Host "2. Launch ChatGPT" -ForegroundColor Yellow
    Write-Host "3. Sign in to your OpenAI account" -ForegroundColor Yellow
    Write-Host "4. Configure your preferred settings" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you successfully set up ChatGPT?")) {
        return $false
    }
    
    return $true
}

function Install-Todoist {
    [CmdletBinding()]
    param()
    
    Write-Status "Installing Todoist..." -Status "Starting" -Color "Yellow"
    
    # Install Todoist
    if (-not (Install-WithWinget -PackageId "Doist.Todoist")) {
        return $false
    }
    
    Write-Host "`nPlease configure Todoist:" -ForegroundColor Yellow
    Write-Host "1. Launch Todoist and sign in" -ForegroundColor Yellow
    Write-Host "2. Bind Alt + T and Alt + Shift + T for quick actions" -ForegroundColor Yellow
    Write-Host "3. Enable 'Start on Startup'" -ForegroundColor Yellow
    Write-Host "4. Enable 'Run in Background'" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you successfully configure Todoist?")) {
        return $false
    }
    
    return $true
}

# Export functions
$exports = @{
    'Install-WorkTools' = ${function:Install-WorkTools}
    'Install-UniGetUI' = ${function:Install-UniGetUI}
    'Install-ChatGPT' = ${function:Install-ChatGPT}
    'Install-Todoist' = ${function:Install-Todoist}
}

return $exports 