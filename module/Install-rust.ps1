# Import utility functions
$utils = . "$PSScriptRoot\utils.ps1"
${function:Test-Command} = $utils['Test-Command']
${function:Install-WithWinget} = $utils['Install-WithWinget']

function Test-RustInstallation {
    return (Test-Command "rustc") -and (Test-Command "cargo")
}

function Install-Rust {
    # First install Visual Studio Build Tools
    Write-Host "Installing Visual Studio Build Tools..." -ForegroundColor Green
    if (-not (Install-WithWinget -PackageId "Microsoft.VisualStudio.2022.BuildTools" -Override "--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended")) {
        Write-Error "Failed to install Visual Studio Build Tools"
        return $false
    }
    
    Write-Host "Installing Rust via rustup..." -ForegroundColor Green
    
    # Download rustup-init
    $rustupInit = "$env:TEMP\rustup-init.exe"
    Invoke-WebRequest -Uri "https://win.rustup.rs" -OutFile $rustupInit
    
    # Install with default options and MSVC toolchain
    & $rustupInit -y --default-toolchain stable-msvc --profile default
    
    # Remove the installer
    Remove-Item $rustupInit -ErrorAction SilentlyContinue
    
    # Refresh environment PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Verify installation
    Write-Host "Verifying Rust installation..." -ForegroundColor Green
    rustc --version
    cargo --version
}

# Return a hashtable of functions
@{
    'Install-Rust' = ${function:Install-Rust}
    'Test-RustInstallation' = ${function:Test-RustInstallation}
}
