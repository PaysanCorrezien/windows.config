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
            if ($layout -match 'Alt Gr dead keys|ALTGR') {
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
        
        if (($layoutFile -and $layoutFile -match 'Alt Gr dead keys|ALTGR') -or 
            ($layoutName -and $layoutName -match 'Alt Gr dead keys|ALTGR')) {
            $code = "0409:$($layout.PSChildName)"
            Write-Host "Found custom layout in registry: $code" -ForegroundColor Cyan
            return $code
        }
    }
    Write-Host "✗ Could not find Alt Gr dead keys layout" -ForegroundColor Red
    return $null
}

function Remove-AllOtherLayouts {
    # Remove all other keyboard layouts from registry
    $customLayout = Get-CustomLayoutCode
    if (-not $customLayout) { return }

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
    if ($enUS) {
        $enUS.InputMethodTips.Clear()
        $enUS.InputMethodTips.Add($customLayout)
        Set-WinUserLanguageList -LanguageList $languageList -Force
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
                Set-WinUserLanguageList $languageList -Force
                
                # Check registry directly
                $layouts = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\*' -ErrorAction SilentlyContinue
                foreach ($layout in $layouts) {
                    if ($layout.PSObject.Properties['Layout File']?.Value -match 'ALTGR' -or 
                        $layout.PSObject.Properties['Layout Display Name']?.Value -match 'ALTGR') {
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
                Write-Host "`n⚠ Please log off and log back on for changes to take effect" -ForegroundColor Yellow
                Write-Host "✓ The Alt Gr dead keys layout will be the only layout available" -ForegroundColor Green
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
