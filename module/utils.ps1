#Requires -RunAsAdministrator
Set-StrictMode -Version 3.0

function Set-Env {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [Parameter(Mandatory=$false)]
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User'
    )

    try {
        $Target = if ($Scope -eq 'User') { 'HKCU' } else { 'HKLM' }
        Write-Verbose "Setting $Name in $Scope scope"
        
        # Get current value to check if we need to append
        $CurrentValue = [System.Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::$Scope)
        
        # For PATH variables, we want to append if it exists
        if ($Name -eq 'PATH' -and $CurrentValue) {
            # Split current PATH into array and check if Value already exists
            $PathArray = $CurrentValue.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($PathArray -notcontains $Value) {
                $Value = $CurrentValue + ';' + $Value
            } else {
                Write-Verbose "Path already contains: $Value"
                return $true
            }
        }

        # Set the environment variable in the registry
        $result = cmd /c "reg add `"$Target\System\CurrentControlSet\Control\Session Manager\Environment`" /v $Name /t REG_EXPAND_SZ /d `"$Value`" /f" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set environment variable: $result"
        }

        # Update the current session
        [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::$Scope)
        
        Write-Host "Successfully set $Name for $Scope"
        return $true
    } catch {
        Write-Error "Failed to set environment variable: $_"
        return $false
    }
}

function Reload-Path {
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Reloading PATH environment variable"

        # Get both System and User PATH
        $SystemPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
        $UserPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')

        # Combine them
        $NewPath = $SystemPath
        if ($UserPath) {
            $NewPath = $NewPath + ';' + $UserPath
        }

        # Update current session
        $env:PATH = $NewPath

        # Broadcast WM_SETTINGCHANGE message to notify other applications
        if (-not ('Win32.NativeMethods' -as [Type])) {
            Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
                [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                public static extern IntPtr SendMessageTimeout(
                    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
                    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        }

        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1a
        $result = [UIntPtr]::Zero
        
        $ret = [Win32.NativeMethods]::SendMessageTimeout(
            $HWND_BROADCAST,
            $WM_SETTINGCHANGE,
            [UIntPtr]::Zero,
            'Environment',
            2,
            5000,
            [ref]$result
        )

        Write-Host "PATH has been reloaded for current session"
        Write-Host "New applications in PATH can now be used without restarting the shell"
        return $true
    } catch {
        Write-Error "Failed to reload PATH: $_"
        return $false
    }
}

function Write-Log {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWORD"
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Log "Created new registry path: $Path"
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value
        Write-Log "Successfully set registry value: $Path\$Name"
    }
    catch {
        Write-Log "Error setting registry value: $_"
        throw
    }
}

function Restart-Explorer {
    try {
        Write-Log "Restarting Explorer to apply changes..."
        Get-Process "explorer" | Stop-Process -Force
        Start-Sleep -Seconds 2
        Start-Process "explorer"
        Write-Log "Explorer restarted successfully"
    }
    catch {
        Write-Log "Error restarting Explorer: $_"
        throw
    }
}

# Export additional utility functions
Export-ModuleMember -Function @(
    'Set-Env',
    'Reload-Path',
    'Write-Log',
    'Set-RegistryValue',
    'Restart-Explorer'
)

# Example usage:
# Set-Env -Name 'PATH' -Value 'C:\Users\admin\AppData\Local\Microsoft\WinGet\Packages\sxyazi.yazi_Microsoft.Winget.Source_8wekyb3d8bbwe\yazi-x86_64-pc-windows-msvc' -Scope 'User' -Verbose
# Reload-Path -Verbose 