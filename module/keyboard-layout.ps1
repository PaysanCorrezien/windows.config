# Run this script with administrator privileges

function Install-CustomLayout {
    [CmdletBinding()]
    param (
        [string]$MsiPath = "$PSScriptRoot\..\intl-alt\intl-alt_amd64.msi"
    )
    
    # Convert to absolute path
    $MsiPath = Resolve-Path $MsiPath -ErrorAction SilentlyContinue
    
    if (-not $MsiPath -or -not (Test-Path $MsiPath)) {
        Write-Host "Error: Custom layout MSI not found at $MsiPath"
        return $false
    }

    try {
        # Install the MSI silently
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$MsiPath`" /quiet" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "✓ Custom layout installed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ Failed to install custom layout (Exit code: $($process.ExitCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "✗ Error installing custom layout: $_" -ForegroundColor Red
        return $false
    }
}

function Set-SingleCustomKeyboard {
    [CmdletBinding()]
    param()

    # Get current language list
    $languageList = Get-WinUserLanguageList

    # Get the en-US language object
    $enUS = $languageList | Where-Object { $_.LanguageTag -eq 'en-US' }
    
    if ($enUS) {
        # Clear existing US layouts
        $enUS.InputMethodTips.Clear()
        
        # Add only the custom layout
        # This is your custom layout, not the standard US-International
        $enUS.InputMethodTips.Add('0409:A0000409')
    }

    # Apply changes and suppress Windows default warnings
    $WarningPreference = 'SilentlyContinue'
    Set-WinUserLanguageList -LanguageList $languageList -Force
    $WarningPreference = 'Continue'

    Write-Host "✓ Custom keyboard layout set as default" -ForegroundColor Green
}

function Set-CustomKeyboardLayout {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$MsiPath = "$PSScriptRoot\..\intl-alt\intl-alt_amd64.msi"
    )

    try {
        if (Install-CustomLayout -MsiPath $MsiPath) {
            # Wait a moment for the installation to complete
            Start-Sleep -Seconds 2
            Set-SingleCustomKeyboard
            Write-Host "`n⚠ Please log off and log back on for changes to take effect" -ForegroundColor Yellow
            return $true
        }
        return $false
    } catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        return $false
    }
}
