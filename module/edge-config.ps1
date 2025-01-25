# Edge Configuration Functions
Set-StrictMode -Version 3.0

function Set-EdgeKeyboardShortcuts {
    [CmdletBinding()]
    param()
    
    Write-Status "Configuring Edge keyboard shortcuts..." -Status "Starting" -Color "Yellow"
    
    # Define the registry path and value
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    $valueName = "ConfigureKeyboardShortcuts"
    $jsonValue = '{"disabled": ["favorite_this_tab", "history", "new_window", "print", "focus_settings_and_more", "select_tab_5", "save_page", "favorites"]}'

    try {
        # Create the registry path if it doesn't exist
        if (-not (Test-Path $registryPath)) {
            Write-Host "Creating Edge policy registry path..." -ForegroundColor Yellow
            New-Item -Path $registryPath -Force | Out-Null
        }

        # Add or update the registry value
        Write-Host "Configuring Edge keyboard shortcuts for SurfingKeys compatibility..." -ForegroundColor Yellow
        New-ItemProperty -Path $registryPath -Name $valueName -Value $jsonValue -PropertyType String -Force | Out-Null
        
        Write-Status "Edge keyboard shortcuts" -Status "Configured" -Color "Green"
        return $true
    }
    catch {
        Write-Warning "Failed to configure Edge keyboard shortcuts: $_"
        return $false
    }
}

function Install-EdgeConfiguration {
    [CmdletBinding()]
    param()
    
    Write-Status "Configuring Microsoft Edge..." -Status "Starting" -Color "Yellow"
    
    Write-Host "`nPlease configure Edge:" -ForegroundColor Yellow
    Write-Host "1. Sign in with your Outlook account" -ForegroundColor Yellow
    Write-Host "2. Sign in with your WorkM account" -ForegroundColor Yellow
    Write-Host "3. Verify sync is working" -ForegroundColor Yellow
    Write-Host "4. Install necessary extensions" -ForegroundColor Yellow
    Write-Host "5. Configure your preferred settings" -ForegroundColor Yellow
    
    # Launch Edge to allow user to configure
    Start-Process "msedge.exe"
    Write-Host "`nPress any key after completing Edge configuration..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    
    return $true
}

# Export functions
$exports = @{
    'Install-EdgeConfiguration' = ${function:Install-EdgeConfiguration}
    'Set-EdgeKeyboardShortcuts' = ${function:Set-EdgeKeyboardShortcuts}
}

return $exports 