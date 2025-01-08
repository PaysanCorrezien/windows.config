# Run this script with administrator privileges

# Import utility functions
$utils = . "$PSScriptRoot\utils.ps1"
${function:Test-Command} = $utils['Test-Command']

function Get-InstalledKeyboardLayouts {
    # Get all installed keyboard layouts
    $layouts = Get-WinUserLanguageList
    $installedLayouts = @()
    
    foreach ($lang in $layouts) {
        $installedLayouts += $lang.InputMethodTips
    }
    
    return $installedLayouts
}

function Test-KeyboardLayout {
    $customLayout = Get-CustomLayoutCode
    $currentLayouts = Get-InstalledKeyboardLayouts
    return $currentLayouts -contains $customLayout
}

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

function Get-CustomLayoutCode {
    # Get all available keyboard layouts
    $layouts = Get-WinUserLanguageList
    foreach ($lang in $layouts) {
        foreach ($layout in $lang.InputMethodTips) {
            # Look specifically for the Alt Gr dead keys layout
            if ($layout -match 'Alt Gr dead keys|ALTGR|a0010409|a0000409') {
                Write-Host "Found custom layout: $layout" -ForegroundColor Cyan
                return $layout
            }
        }
    }
    
    # If not found in language list, check registry
    $layouts = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\*' -ErrorAction SilentlyContinue
    foreach ($layout in $layouts) {
        # Check both Layout File and Layout Display Name properties
        $layoutFile = $layout.PSObject.Properties['Layout File']?.Value
        $layoutName = $layout.PSObject.Properties['Layout Display Name']?.Value
        $layoutId = $layout.PSChildName
        
        if (($layoutFile -and $layoutFile -match 'intl-alt\.dll') -or 
            ($layoutName -and $layoutName -match 'Alt Gr dead keys') -or
            $layoutId -match 'a0010409|a0000409') {
            $code = "0409:$layoutId"
            Write-Host "Found custom layout in registry: $code" -ForegroundColor Cyan
            return $code
        }
    }

    # Last resort: check for the known layout IDs
    $knownLayoutIds = @("0409:a0010409", "0409:a0000409")
    foreach ($layoutId in $knownLayoutIds) {
        Write-Host "Trying known layout ID: $layoutId" -ForegroundColor Yellow
        return $layoutId
    }
}

function Ensure-EnglishLanguage {
    Write-Host "Ensuring US English language is available..." -ForegroundColor Yellow
    $languageList = Get-WinUserLanguageList
    
    # Check if English US is already in the list
    $enUS = $languageList | Where-Object { $_.LanguageTag -eq 'en-US' }
    if (-not $enUS) {
        Write-Host "Adding US English to language list..." -ForegroundColor Yellow
        $enUS = New-WinUserLanguageList en-US
        $languageList.Add($enUS[0])
        Set-WinUserLanguageList $languageList -Force
    }
    return $true
}

function Remove-AllOtherLayouts {
    # Remove all other keyboard layouts from registry
    $customLayout = Get-CustomLayoutCode
    if (-not $customLayout) { return }

    # Ensure we have US English
    Ensure-EnglishLanguage
    
    # Remove from current user
    $userLayoutPath = "HKCU:\Keyboard Layout\Preload"
    if (Test-Path $userLayoutPath) {
        # Remove all existing entries
        Remove-Item -Path $userLayoutPath -Force -ErrorAction SilentlyContinue
        # Create new with only our layout
        New-Item -Path $userLayoutPath -Force | Out-Null
        Set-ItemProperty -Path $userLayoutPath -Name "1" -Value $customLayout -Type String
    }

    # Remove from default user profile
    $defaultUserPath = "C:\Users\Default\NTUSER.DAT"
    if (Test-Path $defaultUserPath) {
        reg load "HKU\Default" $defaultUserPath
        $defaultLayoutPath = "Registry::HKU\Default\Keyboard Layout\Preload"
        
        # Remove all existing entries
        if (Test-Path $defaultLayoutPath) {
            Remove-Item -Path $defaultLayoutPath -Force -ErrorAction SilentlyContinue
        }
        # Create new with only our layout
        New-Item -Path $defaultLayoutPath -Force | Out-Null
        reg add "HKU\Default\Keyboard Layout\Preload" /v "1" /t REG_SZ /d $customLayout /f
        
        [gc]::Collect()
        reg unload "HKU\Default"
    }

    # Also remove from language list
    $languageList = Get-WinUserLanguageList
    $enUS = $languageList | Where-Object { $_.LanguageTag -eq 'en-US' }
    if (-not $enUS) {
        $enUS = New-WinUserLanguageList en-US
        $languageList.Add($enUS[0])
    }
    $enUS.InputMethodTips.Clear()
    $enUS.InputMethodTips.Add($customLayout)
    
    # Remove other languages and set en-US as default
    $languageList = @($enUS)
    Set-WinUserLanguageList $languageList -Force

    # Set as system default
    $systemLayoutPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout"
    if (-not (Test-Path $systemLayoutPath)) {
        New-Item -Path $systemLayoutPath -Force | Out-Null
    }
    Set-ItemProperty -Path $systemLayoutPath -Name "DefaultLayout" -Value $customLayout -Type String

    # Set as default input method
    $inputMethodPath = "HKCU:\Control Panel\International\User Profile"
    if (-not (Test-Path $inputMethodPath)) {
        New-Item -Path $inputMethodPath -Force | Out-Null
    }
    Set-ItemProperty -Path $inputMethodPath -Name "InputMethodOverride" -Value $customLayout -Type String

    # Set default input method for new users
    $defaultInputMethodPath = "HKLM:\SYSTEM\CurrentControlSet\Control\MUI\Settings"
    if (-not (Test-Path $defaultInputMethodPath)) {
        New-Item -Path $defaultInputMethodPath -Force | Out-Null
    }
    Set-ItemProperty -Path $defaultInputMethodPath -Name "PreferredInputMethod" -Value $customLayout -Type String
}

function Set-SingleCustomKeyboard {
    [CmdletBinding()]
    param()

    # Get the correct layout code first
    $layoutCode = Get-CustomLayoutCode
    if (-not $layoutCode) {
        Write-Host "✗ Could not find the Alt Gr dead keys layout. Make sure it's properly installed." -ForegroundColor Red
        return
    }

    # Remove all other layouts and set our custom one
    Remove-AllOtherLayouts

    # Force update the input language
    try {
        $inputLanguage = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
        [System.Windows.Forms.InputLanguage]::CurrentInputLanguage = [System.Windows.Forms.InputLanguage]::FromCulture($inputLanguage)
    }
    catch {
        Write-Host "Note: Could not immediately switch input language. It will be applied after restart." -ForegroundColor Yellow
    }

    # Verify the layout was set correctly
    $currentLayouts = (Get-WinUserLanguageList)[0].InputMethodTips
    if ($currentLayouts.Count -eq 1 -and $currentLayouts[0] -eq $layoutCode) {
        Write-Host "✓ Alt Gr dead keys layout set as the only keyboard layout" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to set layout exclusively" -ForegroundColor Red
        Write-Host "Current layouts: $($currentLayouts -join ', ')" -ForegroundColor Yellow
    }
}

function Set-CustomKeyboardLayout {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$MsiPath = "$PSScriptRoot\..\intl-alt\intl-alt_amd64.msi"
    )

    try {
        # Ensure US English is available first
        Ensure-EnglishLanguage
        
        if (Install-CustomLayout -MsiPath $MsiPath) {
            # Wait for the layout to be registered
            Write-Host "Waiting for layout to be registered..." -ForegroundColor Yellow
            $maxAttempts = 5
            $attempt = 0
            $success = $false

            while ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds 2
                $attempt++
                
                # Refresh language list
                $languageList = Get-WinUserLanguageList
                
                # Ensure US English is still there and has our layout
                $enUS = $languageList | Where-Object { $_.LanguageTag -eq 'en-US' }
                if (-not $enUS) {
                    $enUS = New-WinUserLanguageList en-US
                    $languageList.Add($enUS[0])
                }
                
                Set-WinUserLanguageList $languageList -Force
                
                # Check registry directly for our specific layout
                $layouts = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\*' -ErrorAction SilentlyContinue
                foreach ($layout in $layouts) {
                    if (($layout.PSObject.Properties['Layout File']?.Value -eq 'intl-alt.dll') -or 
                        ($layout.PSChildName -match 'a0010409|a0000409')) {
                        $success = $true
                        break
                    }
                }
                
                if ($success) {
                    break
                }
                
                Write-Host "Attempt $attempt of $maxAttempts - Layout not found yet..." -ForegroundColor Yellow
            }

            if ($success) {
                Write-Host "✓ Layout registered successfully" -ForegroundColor Green
                Set-SingleCustomKeyboard
                Write-Host "`n⚠ A system restart is required for changes to take full effect" -ForegroundColor Yellow
                Write-Host "✓ The Alt Gr dead keys layout will be the only layout available after restart" -ForegroundColor Green
                return $true
            } else {
                Write-Host "✗ Layout registration timed out" -ForegroundColor Red
                return $false
            }
        }
        return $false
    } catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        return $false
    }
}

# Return a hashtable of functions
@{
    'Test-KeyboardLayout' = ${function:Test-KeyboardLayout}
    'Install-CustomLayout' = ${function:Install-CustomLayout}
    'Get-CustomLayoutCode' = ${function:Get-CustomLayoutCode}
    'Remove-AllOtherLayouts' = ${function:Remove-AllOtherLayouts}
    'Set-SingleCustomKeyboard' = ${function:Set-SingleCustomKeyboard}
    'Set-CustomKeyboardLayout' = ${function:Set-CustomKeyboardLayout}
}
