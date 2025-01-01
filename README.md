# Windows Neovim Integration

A set of scripts to integrate Neovim with Windows, providing seamless file opening and context menu integration.

## Features

- Open files in existing WezTerm window with Neovim
- Add "Open with Neovim" to Windows context menu
- Set up file associations for common text files
- Add scripts to system PATH

## Scripts

### nvim-wezterm.bat

Opens files in Neovim within WezTerm:
- If WezTerm is running, opens file in the existing window
- If WezTerm is not running, starts a new instance
- Usage: `nvim-wezterm.bat <file_path>`

### setup-neovim-association.ps1

PowerShell script to set up Windows integration. Requires administrator privileges.

#### Default Installation
```powershell
# Run with default settings (adds everything)
.\setup-neovim-association.ps1
```

#### Custom Installation
```powershell
# Import the script
. .\setup-neovim-association.ps1

# Add only context menu with custom text
Install-NeovimIntegration -AddContextMenu -CustomMenuText "Edit with Neovim"

# Add only PATH and file associations
Install-NeovimIntegration -AddToPath -AddAssociations
```

#### Available Functions

- `Add-ScriptToPath`: Adds scripts directory to system PATH
- `Add-ContextMenu`: Creates "Open with Neovim" context menu entry
- `Add-FileAssociations`: Sets up file type associations
- `Install-NeovimIntegration`: Main function combining all features

#### Default File Associations

The script sets up associations for common text files:
```
.txt, .md, .json, .js, .py, .lua, .vim, .sh, .bat, .ps1,
.config, .yml, .yaml, .xml, .ini, .conf, .log
```

## Requirements

- Windows 10/11
- PowerShell 5.1+
- WezTerm
- Neovim
- Administrator privileges (for setup) 