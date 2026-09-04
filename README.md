# Automated `~/.vimrc` Backup & Sync

This repository includes an automated backup system to track changes in `~/.vimrc`, commit updates, and push them to the remote GitHub repository.

### Files Overview
- **`install.sh`**: Installer script. Copies the repository `vimrc` to `$HOME/.vimrc` on any macOS system, creating a timestamped backup of any existing configuration.
- **`backup_vimrc.sh`**: Core backup script. Compares `~/.vimrc` against the repository `vimrc`, creates a local timestamped snapshot under `~/.vimrc_backups/`, commits changes, and pushes to remote with retry support (for network reconnection on wake-up).
- **`com.c4arl0s.vimrc-backup.plist`**: macOS LaunchAgent configuration. Runs on user login and daily at 09:00 AM (automatically triggers when the MacBook wakes up if missed).
- **`setup.sh`**: Management CLI to install, test, view status, or uninstall the service.

---

### Step 1: Install `~/.vimrc` on Any Mac

Deploy this configuration to your user's home directory:

```bash
# Standard install (safely backs up existing ~/.vimrc if present)
./install.sh

# Install vimrc and automatically download vim-plug
./install.sh --plug

# View all options
./install.sh --help
```

---

### Step 2: Automated Daily / Wake-Up Sync Setup

#### 1. Install macOS LaunchAgent (Recommended for Wake-Up Triggers)
macOS LaunchAgents natively catch up missed schedules as soon as your MacBook wakes up:
```bash
./setup.sh install
```

#### 2. Install Cron Job (Alternative)
If you prefer traditional cron:
```bash
./setup.sh install-cron
```

#### 3. Test the Backup Manually
Run the backup script directly to test detecting changes and pushing:
```bash
./setup.sh test
# Or directly:
./backup_vimrc.sh
```

#### 4. Check Status & Logs
```bash
./setup.sh status
# View live logs:
tail -f ~/Library/Logs/vimrc-backup.log
```

#### 5. JARVIS Voice & Banner Notifications
Whenever the backup check runs upon wake-up, macOS displays a banner notification and speaks an Iron Man / JARVIS style status report using the British voice `Daniel`:
- **In the morning:** *"Good morning, sir. Vim configuration verified. All systems are up to date."*
- **When changes are made:** *"Good morning, sir. New modifications detected in your vim configuration. Changes have been committed and pushed to GitHub."*
- **When offline:** *"Sir, your vim configuration has been backed up locally. Network connection is currently offline; remote push will resume shortly."*

Options in [`backup_vimrc.sh`](backup_vimrc.sh):
- `--no-voice`: Disable speech while keeping banner notifications.
- `--no-notify`: Disable visual banner notifications.
- `--voice <name>`: Choose a different system voice (default: `Daniel`).

#### 6. Uninstall
```bash
./setup.sh uninstall
```
