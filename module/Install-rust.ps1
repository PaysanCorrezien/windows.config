function Install-Rust {
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
