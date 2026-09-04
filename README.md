# Basic configuration of vimrc

Purposes of this project:

1. Understand basic configuracion of vim.
2. Save progress about understanding vim.

```console
" Sets how many lines of history VIM has to remember
set history=500

" Set number line
set number

" set syntax on
syntax on

set nocompatible

" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed

" Highlight searches
set hlsearch

" macro to bold a sentence
" let @b = '<80>kd<80>ku(i**^[<80><fd>a)bi**^[<80><fd>a' 

:set cursorline

command! ToLowercase :%s/.*/\L&/gc
```

<img width="1616" alt="Image" src="https://github.com/user-attachments/assets/846ba699-31fc-4e93-aa27-7ee5fc880ed1" />

---

## Automated `~/.vimrc` Backup & Sync

This repository includes an automated backup system to track changes in `~/.vimrc`, commit updates, and push them to the remote GitHub repository.

### Files Overview
- **`backup_vimrc.sh`**: Core backup script. Compares `~/.vimrc` against the repository `vimrc`, creates a local timestamped snapshot under `~/.vimrc_backups/`, commits changes, and pushes to remote with retry support (for network reconnection on wake-up).
- **`com.c4arl0s.vimrc-backup.plist`**: macOS LaunchAgent configuration. Runs on user login and daily at 09:00 AM (automatically triggers when the MacBook wakes up if missed).
- **`setup.sh`**: Management CLI to install, test, view status, or uninstall the service.

### Quick Setup

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

#### 5. Uninstall
```bash
./setup.sh uninstall
```
