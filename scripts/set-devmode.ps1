function Set-DevMode {
    [CmdletBinding()]
    param (
        [switch]$Force
    )

    begin {
        # Check for admin privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            throw "This function requires administrative privileges. Please run PowerShell as Administrator."
        }
    }

    process {
        try {
            # Create an array of registry changes to make
            $registryChanges = @(
                # Developer Mode
                @{
                    Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
                    Name = "AllowDevelopmentWithoutDevLicense"
                    Type = "DWORD"
                    Value = 1
                },
                # Sudo (Inline Mode)
                @{
                    Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo"
                    Name = "Enabled"
                    Type = "DWORD"
                    Value = 3  # Inline mode
                },
                # PowerShell Execution Policy
                @{
                    Path = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell"
                    Name = "ExecutionPolicy"
                    Type = "String"
                    Value = "Unrestricted"
                }
            )

            # Apply each registry change
            foreach ($change in $registryChanges) {
                # Ensure the registry path exists
                if (-not (Test-Path $change.Path)) {
                    New-Item -Path $change.Path -Force | Out-Null
                }

                # Create or update the registry value
                New-ItemProperty -Path $change.Path -Name $change.Name -PropertyType $change.Type -Value $change.Value -Force | Out-Null
            }

            # Set execution policy using PowerShell command as well (belt and suspenders approach)
            Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force:$Force

            # Output success message
            Write-Host "Development environment has been configured successfully:" -ForegroundColor Green
            Write-Host "✓ Developer Mode enabled" -ForegroundColor Green
            Write-Host "✓ Sudo command enabled (inline mode)" -ForegroundColor Green
            Write-Host "✓ PowerShell execution policy set to Unrestricted" -ForegroundColor Green
            Write-Host "`nNote: Some changes may require a system restart to take effect." -ForegroundColor Yellow
        }
        catch {
            Write-Error "Failed to configure development environment: $_"
            throw
        }
    }
}
