# Caelestia

Modern desktop configuration for Hyprland with Quickshell.

## Installation
```bash
curl -fsSL https://raw.githubusercontent.com/caelestia-dots/shell/main/install.sh | bash
```

## Features
- Application launcher with search
- Status bar with system info
- Session management
- Dynamic wallpapers
- Clean notifications

## Configuration
Main config: `~/.config/caelestia/config.json`
Custom Hyprland settings: `~/.config/caelestia/hypr-user.conf`

## Requirements
- Hyprland
- Qt6
- Quickshell
- Systemd

## Troubleshooting
Screen flickering? Add `misc { vrr = 0 }` to `hypr-user.conf`.

Built with Quickshell by the Hyprland community.
