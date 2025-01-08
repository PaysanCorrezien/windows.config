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
    # First try to find the layout in the registry
    $layouts = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\*' -ErrorAction SilentlyContinue
    foreach ($layout in $layouts) {
        # Look specifically for our custom Alt International layout
        if ($layout.PSObject.Properties['Layout File']?.Value -eq 'intl-alt.dll') {
            $layoutId = $layout.PSChildName
            $code = "0409:$layoutId"
            Write-Host "Found Alt International layout in registry: $code" -ForegroundColor Cyan
            return $code
        }
    }
    
    # If not found in registry, check language list
    $layouts = Get-WinUserLanguageList
    foreach ($lang in $layouts) {
        foreach ($layout in $lang.InputMethodTips) {
            # Look for our specific Alt International layout
            if ($layout -match 'intl-alt') {
                Write-Host "Found Alt International layout in language list: $layout" -ForegroundColor Cyan
                return $layout
            }
        }
    }

    # If still not found, check for the specific layout ID we installed
    $layoutId = "a0000409"  # This is the ID of our Alt International layout
    $code = "0409:$layoutId"
    Write-Host "Using default Alt International layout ID: $code" -ForegroundColor Yellow
    return $code
}

function Ensure-EnglishLanguage {
    Write-Host "Setting US English as system language..." -ForegroundColor Yellow
    
    # Set system locale to English
    Set-WinSystemLocale -SystemLocale en-US
    
    # Set user locale to English
    Set-WinUserLanguageList en-US -Force
    
    # Set display language
    Set-WinUILanguageOverride -Language en-US
    
    # Set default input language to English
    Set-WinDefaultInputMethodOverride -InputTip "0409:00000409"
    
    # Force Windows display language
    $languagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\MUI\Settings"
    if (-not (Test-Path $languagePath)) {
        New-Item -Path $languagePath -Force | Out-Null
    }
    Set-ItemProperty -Path $languagePath -Name "PreferredUILanguages" -Value "en-US" -Type MultiString
    
    # Set system UI language
    $languageList = Get-WinUserLanguageList
    $languageList.Clear()
    $enUS = New-WinUserLanguageList en-US
    $languageList.Add($enUS[0])
    Set-WinUserLanguageList $languageList -Force
    
    # Set regional settings to English
    Set-Culture en-US
    
    # Set additional registry keys for language settings
    $regPaths = @(
        "HKCU:\Control Panel\International",
        "HKCU:\Control Panel\Desktop",
        "HKLM:\SYSTEM\CurrentControlSet\Control\MUI\UILanguages\en-US"
    )
    
    foreach ($path in $regPaths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
    }
    
    # Set locale settings
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "LocaleName" -Value "en-US"
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sLanguage" -Value "ENU"
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sSystemLocale" -Value "en-US"
    
    # Lock language settings
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "PreferredUILanguages" -Value "en-US" -Type MultiString
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\MUI\UILanguages\en-US" -Name "Default" -Value 1 -Type DWord
    
    return $true
}

function Remove-AllOtherLayouts {
    # Remove all other keyboard layouts from registry
    $customLayout = Get-CustomLayoutCode
    if (-not $customLayout) { 
        Write-Host "✗ Could not find Alt International layout. Please ensure it's properly installed." -ForegroundColor Red
        return 
    }

    Write-Host "Setting Alt International layout ($customLayout) as default..." -ForegroundColor Yellow

    # Force English and remove other languages first
    Ensure-EnglishLanguage
    
    # Remove from current user
    $userLayoutPath = "HKCU:\Keyboard Layout\Preload"
    if (Test-Path $userLayoutPath) {
        Remove-Item -Path $userLayoutPath -Force -ErrorAction SilentlyContinue
        New-Item -Path $userLayoutPath -Force | Out-Null
        Set-ItemProperty -Path $userLayoutPath -Name "1" -Value $customLayout -Type String
    }

    # Remove from default user profile
    $defaultUserPath = "C:\Users\Default\NTUSER.DAT"
    if (Test-Path $defaultUserPath) {
        reg load "HKU\Default" $defaultUserPath
        $defaultLayoutPath = "Registry::HKU\Default\Keyboard Layout\Preload"
        
        if (Test-Path $defaultLayoutPath) {
            Remove-Item -Path $defaultLayoutPath -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $defaultLayoutPath -Force | Out-Null
        reg add "HKU\Default\Keyboard Layout\Preload" /v "1" /t REG_SZ /d $customLayout /f
        
        [gc]::Collect()
        reg unload "HKU\Default"
    }

    # Set keyboard layout in multiple registry locations
    $regPaths = @(
        "HKCU:\Keyboard Layout\Preload",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout",
        "HKCU:\Control Panel\International\User Profile",
        "HKLM:\SYSTEM\CurrentControlSet\Control\MUI\Settings",
        "HKCU:\Control Panel\International",
        "HKLM:\SOFTWARE\Microsoft\CTF\Assemblies\0x00000409\{34745C63-B2F0-4784-8B67-5E12C8701A31}"
    )

    foreach ($path in $regPaths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
    }

    # Set default layout in various locations
    Set-ItemProperty -Path "HKCU:\Keyboard Layout\Preload" -Name "1" -Value $customLayout -Type String
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "DefaultLayout" -Value $customLayout -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International\User Profile" -Name "InputMethodOverride" -Value $customLayout -Type String
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\MUI\Settings" -Name "PreferredInputMethod" -Value $customLayout -Type String
    
    # Force keyboard layout
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "DefaultInputMethodOverride" -Value $customLayout -Type String
    
    # Set layout as default for text services
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\CTF\Assemblies\0x00000409\{34745C63-B2F0-4784-8B67-5E12C8701A31}" -Name "Default" -Value $customLayout -Type String
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\CTF\Assemblies\0x00000409\{34745C63-B2F0-4784-8B67-5E12C8701A31}" -Name "Profile" -Value $customLayout -Type String
    
    # Update language list
    $languageList = Get-WinUserLanguageList
    $enUS = $languageList | Where-Object { $_.LanguageTag -eq 'en-US' }
    if (-not $enUS) {
        $enUS = New-WinUserLanguageList en-US
        $languageList.Add($enUS[0])
    }
    $enUS.InputMethodTips.Clear()
    $enUS.InputMethodTips.Add($customLayout)
    
    # Set as only language
    $languageList = @($enUS)
    Set-WinUserLanguageList $languageList -Force

    # Remove any other preloaded layouts
    $substitutes = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout\Substitutes" -ErrorAction SilentlyContinue
    if ($substitutes) {
        Remove-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout\Substitutes" -Force -ErrorAction SilentlyContinue
    }
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
        Write-Host "✓ System language set to English (US)" -ForegroundColor Green
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
