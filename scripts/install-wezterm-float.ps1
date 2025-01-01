# install-wezterm-float.ps1

$REPO_PATH = "$env:USERPROFILE\repo\wezterm"
$INSTALL_DIR = "C:\Program Files\WezTerm"
$BRANCH_NAME = "float-pane"

# Function to check if a command exists
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Function to check and install dependencies
function Install-Dependencies {
    Write-Host "Checking dependencies..."
    
    # Check for Perl
    if (-not (Test-Command "perl")) {
        Write-Host "Perl not found. Installing Strawberry Perl..."
        winget install StrawberryPerl.StrawberryPerl
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    
    # Check for Rust
    if (-not (Test-Command "rustc")) {
        Write-Host "Rust not found. Installing Rust..."
        Invoke-WebRequest https://win.rustup.rs/x86_64 -OutFile rustup-init.exe
        .\rustup-init.exe -y
        Remove-Item rustup-init.exe
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    
    # Check for Visual Studio Build Tools
    if (-not (Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe")) {
        Write-Host "Visual Studio Build Tools not found. Please install Visual Studio 2019 or newer with C++ build tools."
        Write-Host "Download from: https://visualstudio.microsoft.com/visual-cpp-build-tools/"
        Exit 1
    }
}

# Rest of your existing functions...
function Stop-WezTerm {
    Write-Host "Stopping WezTerm processes if running..."
    Get-Process wezterm-gui -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process wezterm -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}

function Backup-WezTerm {
    if (Test-Path $INSTALL_DIR) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backup_path = "${INSTALL_DIR}_backup_$timestamp"
        Write-Host "Backing up existing WezTerm installation to: $backup_path"
        Move-Item -Path $INSTALL_DIR -Destination $backup_path -Force
    }
}

# Main script execution
Write-Host "Checking and installing dependencies..."
Install-Dependencies

# Clone or update repository
if (-not (Test-Path $REPO_PATH)) {
    Write-Host "Cloning WezTerm repository..."
    git clone https://github.com/wez/wezterm.git $REPO_PATH
    Set-Location $REPO_PATH
    git fetch origin "pull/5576/head:$BRANCH_NAME"
    git checkout $BRANCH_NAME
} else {
    Write-Host "Updating existing repository..."
    Set-Location $REPO_PATH
    git fetch origin
    git checkout $BRANCH_NAME
    git pull origin $BRANCH_NAME
}

# Build WezTerm
Write-Host "Building WezTerm in release mode (this may take a while)..."
cargo build --release

# Check if build was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed! Exiting..."
    exit 1
}

# Install new version
Write-Host "Installing new WezTerm version..."
Stop-WezTerm
Backup-WezTerm

# Create new installation directory
New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null

# Copy new files
Write-Host "Copying new files to $INSTALL_DIR"
Copy-Item "$REPO_PATH\target\release\wezterm*.exe" $INSTALL_DIR

Write-Host "Installation complete! New float-pane version of WezTerm has been installed."
Write-Host "You can now start WezTerm normally."
