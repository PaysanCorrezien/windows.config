# Get the correct Winget packages path using LocalAppData
$wingetPackagesPath = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"

# Get current user's PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")

# Function to find the most likely binary directory in a package folder
function Get-PackageBinaryPath {
    param (
        [string]$PackagePath
    )
    
    # Common binary directory names
    $binDirPatterns = @(
        'bin',
        'binary',
        '*.exe',
        'cmd',
        'cli'
    )
    
    # First, search directly in the package directory
    $exes = Get-ChildItem -Path $PackagePath -Filter "*.exe" -File
    if ($exes) {
        return $PackagePath
    }
    
    # Then look for common binary directory patterns
    foreach ($pattern in $binDirPatterns) {
        $binDirs = Get-ChildItem -Path $PackagePath -Filter $pattern -Directory -Recurse
        foreach ($dir in $binDirs) {
            $exes = Get-ChildItem -Path $dir.FullName -Filter "*.exe" -File
            if ($exes) {
                return $dir.FullName
            }
        }
    }
    
    # If no obvious bin directory, search all subdirectories for executables
    $allDirs = Get-ChildItem -Path $PackagePath -Directory -Recurse
    foreach ($dir in $allDirs) {
        $exes = Get-ChildItem -Path $dir.FullName -Filter "*.exe" -File
        if ($exes) {
            return $dir.FullName
        }
    }
    
    return $null
}

Write-Host "Scanning Winget packages directory: $wingetPackagesPath"

if (-not (Test-Path $wingetPackagesPath)) {
    Write-Host "Winget packages directory not found at: $wingetPackagesPath"
    Write-Host "Make sure Winget is installed and you have installed some packages."
    exit
}

# Get all package directories
$packageDirs = Get-ChildItem -Path $wingetPackagesPath -Directory

$binPaths = @()
$foundExes = @()

foreach ($packageDir in $packageDirs) {
    Write-Host "`nAnalyzing package: $($packageDir.Name)"
    
    $binPath = Get-PackageBinaryPath -PackagePath $packageDir.FullName
    if ($binPath) {
        $exes = Get-ChildItem -Path $binPath -Filter "*.exe" -File
        foreach ($exe in $exes) {
            Write-Host "Found executable: $($exe.FullName)"
            $foundExes += $exe.FullName
        }
        $binPaths += $binPath
    }
}

Write-Host "`nFound executables:"
$foundExes | ForEach-Object { Write-Host $_ }

# Check which directories are not in PATH and add them
$pathDirs = $userPath -split ';' | Where-Object { $_ }
$dirsToAdd = @()

foreach ($dir in $binPaths) {
    if ($pathDirs -notcontains $dir) {
        Write-Host "`nAdding to PATH: $dir"
        $dirsToAdd += $dir
    }
}

if ($dirsToAdd.Count -gt 0) {
    # Combine existing PATH with new directories
    $newPath = ($userPath, ($dirsToAdd -join ';')) -join ';'
    
    # Update user's PATH
    [Environment]::SetEnvironmentVariable(
        "PATH",
        $newPath,
        "User"
    )
    
    Write-Host "`nPATH has been updated. New directories added: $($dirsToAdd.Count)"
} else {
    Write-Host "`nNo new directories needed to be added to PATH"
}

# Print the final PATH for verification
Write-Host "`nUpdated PATH directories:"
[Environment]::GetEnvironmentVariable("PATH", "User") -split ';' | Where-Object { $_ } | ForEach-Object { Write-Host $_ }
