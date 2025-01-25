# Application Installation Functions
Set-StrictMode -Version 3.0

function Install-Nextcloud
{
  [CmdletBinding()]
  param()
    
  Write-Status "Installing Nextcloud..." -Status "Starting" -Color "Yellow"
    
  try
  {
    # First check if already installed
    $checkOutput = winget list --id Nextcloud.NextcloudDesktop 2>&1
    if ($checkOutput -match "Nextcloud.NextcloudDesktop")
    {
      Write-Host "Nextcloud is already installed" -ForegroundColor Green
      return $true
    }
        
    # Install Nextcloud
    if (-not (Install-WithWinget -PackageId "Nextcloud.NextcloudDesktop"))
    {
      return $false
    }

    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Launch Nextcloud" -ForegroundColor Yellow
    Write-Host "2. Log in to your account" -ForegroundColor Yellow
    Write-Host "3. Configure sync settings" -ForegroundColor Yellow
    Write-Host "4. Verify sync is working" -ForegroundColor Yellow
        
    if (-not (Get-UserConfirmation "Did you successfully set up Nextcloud and verify sync is working?"))
    {
      return $false
    }
        
    if (-not (Get-UserConfirmation "Did you successfully set up Nextcloud and verify sync is working?"))
    {
      return $false
    }
        
    return $true
  } catch
  {
    Write-Warning "Failed to install Nextcloud: $_"
    return $false
  }
}

function Install-KeePassXC
{
  [CmdletBinding()]
  param()
    
  Write-Status "Installing KeePassXC..." -Status "Starting" -Color "Yellow"
    
  try
  {
    # First check if already installed
    $checkOutput = winget list --id KeePassXCTeam.KeePassXC 2>&1
    if ($checkOutput -match "KeePassXCTeam.KeePassXC")
    {
      Write-Host "KeePassXC is already installed" -ForegroundColor Green
      return $true
    }
        
    # Install KeePassXC
    if (-not (Install-WithWinget -PackageId "KeePassXCTeam.KeePassXC"))
    {
      return $false
    }
        
    Write-Host "`nPlease configure KeePassXC:" -ForegroundColor Yellow
    Write-Host "1. Enable SSH Agent integration" -ForegroundColor Yellow
    Write-Host "2. Allow browser authentication" -ForegroundColor Yellow
    Write-Host "3. Test SSH key integration" -ForegroundColor Yellow
    Write-Host "4. Test browser integration" -ForegroundColor Yellow
        
    # Launch KeePassXC
    Start-Process "keepassxc.exe"
    Write-Host "`nPress any key after completing KeePassXC setup..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
    return $true
  } catch
  {
    Write-Warning "Failed to install KeePassXC: $_"
    return $false
  }
}

function Install-GnuPG
{
  [CmdletBinding()]
  param()
    
  Write-Status "Installing GnuPG..." -Status "Starting" -Color "Yellow"
    
  # Install GnuPG
  if (-not (Install-WithWinget -PackageId "GnuPG.GnuPG"))
  {
    return $false
  }
    
  # Reload PATH after GPG installation
  Reload-Path
    
  # Configure Git to use GPG
  if (-not (Invoke-ExternalCommand -Command 'git config --global gpg.program "C:\Program Files (x86)\GnuPG\bin\gpg.exe"' `
        -Description "Configuring Git GPG"))
  {
    return $false
  }
    
  Write-Host "`nPlease complete GPG setup:" -ForegroundColor Yellow
  Write-Host "1. Retrieve your private key (private.asc) from your password manager" -ForegroundColor Yellow
  Write-Host "2. Import your key using:" -ForegroundColor Yellow
  Write-Host "   gpg --import private.asc" -ForegroundColor Cyan
  Write-Host "3. Verify the key was imported using:" -ForegroundColor Yellow
  Write-Host "   gpg --list-secret-keys" -ForegroundColor Cyan
    
  Write-Host "`nPress any key after completing GPG setup..." -ForegroundColor Yellow
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    
  return $true
}

function Install-EdgeConfiguration
{
  [CmdletBinding()]
  param()
    
  Write-Status "Configuring Microsoft Edge..." -Status "Starting" -Color "Yellow"
    
  Write-Host "`nPlease configure Edge:" -ForegroundColor Yellow
  Write-Host "1. Sign in with your Outlook account" -ForegroundColor Yellow
  Write-Host "2. Sign in with your WorkM account" -ForegroundColor Yellow
  Write-Host "3. Verify sync is working" -ForegroundColor Yellow
  Write-Host "4. Install necessary extensions" -ForegroundColor Yellow
  Write-Host "5. Configure your preferred settings" -ForegroundColor Yellow
    
  if (-not (Get-UserConfirmation "Did you successfully configure Edge with both accounts?"))
  {
    return $false
  }
    
  return $true
}

function Install-PowerToys
{
  [CmdletBinding()]
  param()
    
  Write-Status "Installing PowerToys..." -Status "Starting" -Color "Yellow"
    
  # Install PowerToys
  if (-not (Install-WithWinget -PackageId "Microsoft.PowerToys"))
  {
    return $false
  }
    
  # Reload PATH after PowerToys installation
  Reload-Path
    
  Write-Host "`nPlease configure PowerToys:" -ForegroundColor Yellow
  Write-Host "1. Launch PowerToys" -ForegroundColor Yellow
  Write-Host "2. Configure FancyZones for window management" -ForegroundColor Yellow
  Write-Host "3. Set up PowerToys Run shortcuts" -ForegroundColor Yellow
  Write-Host "4. Configure any other modules you need" -ForegroundColor Yellow
  Write-Host "5. Enable 'Run at startup'" -ForegroundColor Yellow
    
  if (-not (Get-UserConfirmation "Did you successfully configure PowerToys?"))
  {
    return $false
  }
    
  return $true
}

# Export functions
$exports = @{
  'Install-Nextcloud' = ${function:Install-Nextcloud}
  'Install-KeePassXC' = ${function:Install-KeePassXC}
  'Install-GnuPG' = ${function:Install-GnuPG}
  'Install-EdgeConfiguration' = ${function:Install-EdgeConfiguration}
  'Install-PowerToys' = ${function:Install-PowerToys}
}

return $exports 
