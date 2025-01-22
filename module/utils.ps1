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

function Write-Status {
    param(
        [string]$Message,
        [string]$Status,
        [string]$Color = "Green"
    )
    Write-Host "$Message".PadRight(50) -NoNewline
    Write-Host "[$Status]" -ForegroundColor $Color
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

function Set-StageFlag {
    param (
        [Parameter(Mandatory=$true)]
        [string]$StageName
    )
    
    try {
        $flagsDir = Join-Path $PSScriptRoot "..\flags"
        if (-not (Test-Path $flagsDir)) {
            New-Item -ItemType Directory -Path $flagsDir -Force | Out-Null
        }
        
        $flagPath = Join-Path $flagsDir "$StageName.txt"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $timestamp | Set-Content $flagPath -Force
        Write-Verbose "Created flag for stage: $StageName"
        return $true
    }
    catch {
        Write-Error "Failed to create flag file for stage $StageName`: $_"
        return $false
    }
}

function Test-StageFlag {
    param (
        [Parameter(Mandatory=$true)]
        [string]$StageName
    )
    
    $flagPath = Join-Path $PSScriptRoot "..\flags\$StageName.txt"
    return Test-Path $flagPath
}

function Invoke-ExternalCommand {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [string]$Description,
        [switch]$UseShell
    )
    
    try {
        Write-Status "$Description" -Status "Starting" -Color "Yellow"
        
        if ($UseShell) {
            $scriptBlock = [Scriptblock]::Create($Command)
            $result = & $scriptBlock
        } else {
            $result = Invoke-Expression -Command $Command
        }
        
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Status "$Description" -Status "Failed (Exit: $LASTEXITCODE)" -Color "Red"
            return $false
        }
        
        Write-Status "$Description" -Status "Completed" -Color "Green"
        return $true
    }
    catch {
        Write-Status "$Description" -Status "Error: $_" -Color "Red"
        return $false
    }
}

function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

function Install-WithWinget {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [string]$Source = "winget",
        [string[]]$AdditionalArguments = @(),
        [switch]$NoCheckAlreadyInstalled
    )

    try {
        # First check if already installed (unless explicitly skipped)
        if (-not $NoCheckAlreadyInstalled) {
            $checkOutput = winget list --id $PackageId 2>&1
            if ($checkOutput -match $PackageId) {
                Write-Host "$PackageId is already installed" -ForegroundColor Green
                return $true
            }
        }

        # Build the installation command
        $baseArgs = @(
            "install",
            "--exact",
            "--id",
            $PackageId,
            "--accept-source-agreements",
            "--accept-package-agreements"
        )
        
        if ($Source -ne "winget") {
            $baseArgs += @("--source", $Source)
        }
        
        $baseArgs += $AdditionalArguments
        
        # Try to install with detailed error capture
        Write-Host "Installing $PackageId..." -ForegroundColor Yellow
        $installOutput = & winget $baseArgs 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $errorDetail = $installOutput | Out-String
            $errorMessage = "Failed to install $PackageId (Exit code: $exitCode)`nInstallation output:`n$errorDetail"
            Write-Host "`nYou can try installing $PackageId manually using:" -ForegroundColor Yellow
            Write-Host "winget install --exact --id $PackageId $(if($Source -ne 'winget'){`"--source $Source`"})" -ForegroundColor Cyan
            throw $errorMessage
        }

        Write-Host "$PackageId installation completed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        $errorDetail = $_.Exception.Message
        $stackTrace = $_.ScriptStackTrace
        Write-Error "Failed to install $PackageId with error: $errorDetail`nStack trace: $stackTrace"
        return $false
    }
}

function Update-GitRepository {
    param (
        [Parameter(Mandatory=$true)]
        [string]$RepoPath,
        [string]$Description = "repository"
    )
    
    try {
        if (-not (Test-Path $RepoPath)) {
            Write-Warning "$Description not found at: $RepoPath"
            return $false
        }
        
        Push-Location $RepoPath
        Write-Host "Updating $Description..." -ForegroundColor Yellow
        
        # Fetch latest changes
        git fetch origin
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to fetch updates"
        }
        
        # Get current branch
        $currentBranch = git rev-parse --abbrev-ref HEAD
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get current branch"
        }
        
        # Pull changes
        git pull origin $currentBranch
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to pull updates"
        }
        
        Write-Host "$Description updated successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to update $Description`: $_"
        return $false
    }
    finally {
        Pop-Location
    }
}

function Get-UserConfirmation {
    param (
        [string]$Message
    )
    $title = "Confirmation Required"
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "The action was successful")
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "The action failed or needs to be retried")
    )
    $decision = $Host.UI.PromptForChoice($title, $Message, $choices, 0)
    return $decision -eq 0
}

function Handle-Error {
    param (
        [string]$ErrorMessage,
        [string]$Stage,
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )
    Write-Error $ErrorMessage
    Write-Host "`nAn error occurred during $Stage." -ForegroundColor Red
    
    if ($ErrorRecord) {
        Write-Host "`nDetailed Error Information:" -ForegroundColor Yellow
        Write-Host "Exception Type: $($ErrorRecord.Exception.GetType().FullName)" -ForegroundColor Yellow
        Write-Host "Exception Message: $($ErrorRecord.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Error Category: $($ErrorRecord.CategoryInfo.Category)" -ForegroundColor Yellow
        if ($ErrorRecord.ScriptStackTrace) {
            Write-Host "`nStack Trace:" -ForegroundColor Yellow
            Write-Host $ErrorRecord.ScriptStackTrace -ForegroundColor Gray
        }
    }

    Write-Host "`nYou can investigate the error before deciding to continue or exit." -ForegroundColor Yellow
    if (-not (Get-UserConfirmation "Would you like to continue with the rest of the installation?")) {
        Write-Host "Script stopped. You can run it again after fixing the issue." -ForegroundColor Yellow
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false
    }
    Write-Host "Continuing with the next step..." -ForegroundColor Green
    return $true
}

function Pause-Script {
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Exit-Script {
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
}

# Export functions
$exports = @{
    'Write-Status' = ${function:Write-Status}
    'Write-Log' = ${function:Write-Log}
    'Set-StageFlag' = ${function:Set-StageFlag}
    'Test-StageFlag' = ${function:Test-StageFlag}
    'Invoke-ExternalCommand' = ${function:Invoke-ExternalCommand}
    'Set-Env' = ${function:Set-Env}
    'Reload-Path' = ${function:Reload-Path}
    'Test-Command' = ${function:Test-Command}
    'Install-WithWinget' = ${function:Install-WithWinget}
    'Update-GitRepository' = ${function:Update-GitRepository}
    'Get-UserConfirmation' = ${function:Get-UserConfirmation}
    'Handle-Error' = ${function:Handle-Error}
    'Pause-Script' = ${function:Pause-Script}
    'Exit-Script' = ${function:Exit-Script}
}

return $exports

# Example usage:
# Set-Env -Name 'PATH' -Value 'C:\Users\admin\AppData\Local\Microsoft\WinGet\Packages\sxyazi.yazi_Microsoft.Winget.Source_8wekyb3d8bbwe\yazi-x86_64-pc-windows-msvc' -Scope 'User' -Verbose
# Reload-Path -Verbose 