# NOTE: disable edge shortcut for best experience with surfingkeys
# Define the registry path and value
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$valueName = "ConfigureKeyboardShortcuts"
$jsonValue = '{"disabled": ["favorite_this_tab", "history", "new_window", "print", "focus_settings_and_more", "select_tab_5", "save_page", "favorites"]}'

# Create the registry path if it doesn't exist
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Add or update the registry value
New-ItemProperty -Path $registryPath -Name $valueName -Value $jsonValue -PropertyType String -Force

winget install --id lsd-rs.lsd`
winget install --source winget --exact --id JohnMacFarlane.Pandoc
winget install --id=Starship.Starship -e
winget install --id=Yubico.YubikeyManager -e
# YUbikey login from their website, no scoop or winget

winget install --id=Yubico.Authenticator -e # yubioath-desktop
winget install --id=sharkdp.fd -e
# enable sshfs-win too
winget install SSHFS-Win.SSHFS-Win

scoop install main/termusic
scoop install ouch

#NOTE: disable print screen key
 Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "PrintScreenKeyForSnippingEnabled" -Value 0

# added rustscan to path:
# sysdm.cpl :
# C:\Users\admin\repo\windows.config\apps\rustscan-2.3.0-x86_64-windows\
# same for sshfs 
##C:\Program Files\SSHFS-Win\bin
## and keepasxc cli too:
# C:\Program Files\KeePassXC
#
#TODO: ADD flameshot to start menu , same chatgpt

#TODO: keepassxc enable browser integreation / ssh agent

