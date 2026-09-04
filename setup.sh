#!/usr/bin/env bash
# ==============================================================================
# setup.sh
#
# Setup and management script for automated vimrc backup on macOS.
# Supports macOS LaunchAgent (recommended for wake-up triggers) and Cron.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_NAME="com.c4arl0s.vimrc-backup.plist"
PLIST_SRC="${SCRIPT_DIR}/${PLIST_NAME}"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup_vimrc.sh"
LOG_FILE="${HOME}/Library/Logs/vimrc-backup.log"

show_help() {
    cat <<EOF
Vimrc Backup Setup Utility for macOS

Usage: $(basename "$0") <command>

Commands:
  install           Install and activate macOS LaunchAgent (Runs on login & wake-up)
  install-cron      Install a traditional cron job (crontab)
  check-plugins     Verify if declared vim plugins are installed or missing
  test              Run backup_vimrc.sh immediately and display log output
  status            Check whether the LaunchAgent, Cron, and Plugins are configured
  uninstall         Unload and remove LaunchAgent and Cron backup tasks
  help              Display this help message

Why LaunchAgent is recommended on macOS:
  macOS LaunchAgents natively catch up and execute when your MacBook wakes up if the
  scheduled time passed while asleep. Traditional cron does not run missed jobs on wake.
EOF
}

check_prerequisites() {
    if [ ! -f "${BACKUP_SCRIPT}" ]; then
        echo "Error: ${BACKUP_SCRIPT} not found." >&2
        exit 1
    fi
    chmod +x "${BACKUP_SCRIPT}"
}

install_launchagent() {
    check_prerequisites
    mkdir -p "${LAUNCH_AGENTS_DIR}"
    mkdir -p "$(dirname "${LOG_FILE}")"

    echo "Configuring LaunchAgent..."

    # Generate plist with exact local paths
    cat > "${PLIST_DEST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.c4arl0s.vimrc-backup</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${BACKUP_SCRIPT}</string>
    </array>

    <!-- Run when user logs in -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Schedule to run daily at 09:00 AM.
         If the MacBook is asleep at 09:00 AM, launchd automatically
         runs this job immediately when the computer wakes up. -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>

    <key>StandardErrorPath</key>
    <string>${LOG_FILE}</string>
</dict>
</plist>
EOF

    # Validate plist
    if command -v plutil >/dev/null 2>&1; then
        plutil -lint "${PLIST_DEST}" >/dev/null
    fi

    # Unload if already loaded, then load
    launchctl unload "${PLIST_DEST}" 2>/dev/null || true
    if launchctl load "${PLIST_DEST}" 2>/dev/null; then
        echo "Successfully installed and loaded LaunchAgent: ${PLIST_DEST}"
    else
        echo "Note: Could not run 'launchctl load' directly (may need terminal permission)."
        echo "You can manually load it anytime by running:"
        echo "  launchctl load ${PLIST_DEST}"
    fi

    echo ""
    echo "Summary:"
    echo "- Script: ${BACKUP_SCRIPT}"
    echo "- Plist:  ${PLIST_DEST}"
    echo "- Logs:   ${LOG_FILE}"
}

install_cron() {
    check_prerequisites
    local cron_job="0 9 * * * /bin/bash ${BACKUP_SCRIPT} --quiet"

    echo "Attempting to add cron entry..."
    if crontab -l 2>/dev/null | grep -Fq "${BACKUP_SCRIPT}"; then
        echo "Cron job already exists for ${BACKUP_SCRIPT}."
    else
        # Append without overwriting existing jobs
        (crontab -l 2>/dev/null || true; echo "${cron_job}") | crontab - 2>/dev/null || {
            echo "Warning: crontab command failed (macOS requires Full Disk Access for cron)."
            echo "To manually add it, open 'crontab -e' and paste:"
            echo "  ${cron_job}"
            return 1
        }
        echo "Successfully added to crontab:"
        echo "  ${cron_job}"
    fi
}

run_test() {
    check_prerequisites
    echo "Running ${BACKUP_SCRIPT} in test mode..."
    "${BACKUP_SCRIPT}"
    echo ""
    echo "Recent log entries from ${LOG_FILE}:"
    echo "------------------------------------------------------------"
    if [ -f "${LOG_FILE}" ]; then
        tail -n 15 "${LOG_FILE}"
    else
        echo "(No log file created yet)"
    fi
}

check_status() {
    echo "=== Vimrc Backup Status ==="
    echo "Repository: ${SCRIPT_DIR}"
    echo "Backup script: ${BACKUP_SCRIPT} $([ -x "${BACKUP_SCRIPT}" ] && echo '[executable]' || echo '[not executable]')"
    echo ""

    echo "--- LaunchAgent Status ---"
    if [ -f "${PLIST_DEST}" ]; then
        echo "Plist installed at: ${PLIST_DEST}"
        if launchctl list 2>/dev/null | grep -q "com.c4arl0s.vimrc-backup"; then
            echo "Service state: ACTIVE (Loaded in launchd)"
        else
            echo "Service state: NOT LOADED (Run './setup.sh install' to activate)"
        fi
    else
        echo "LaunchAgent is not installed."
    fi
    echo ""

    echo "--- Cron Status ---"
    if crontab -l 2>/dev/null | grep -Fq "${BACKUP_SCRIPT}"; then
        echo "Cron state: ACTIVE in crontab"
        crontab -l 2>/dev/null | grep -F "${BACKUP_SCRIPT}"
    else
        echo "Cron state: NOT CONFIGURED"
    fi
    echo ""

    echo "--- Vim Plugins Status ---"
    if [ -x "${SCRIPT_DIR}/install.sh" ]; then
        "${SCRIPT_DIR}/install.sh" --check-plugins
    else
        echo "install.sh not found."
    fi
    echo ""

    echo "--- Recent Log Entries (${LOG_FILE}) ---"
    if [ -f "${LOG_FILE}" ]; then
        tail -n 10 "${LOG_FILE}"
    else
        echo "No log file found."
    fi
}

uninstall() {
    echo "Uninstalling automated vimrc backup..."

    if [ -f "${PLIST_DEST}" ]; then
        launchctl unload "${PLIST_DEST}" 2>/dev/null || true
        rm -f "${PLIST_DEST}"
        echo "Removed LaunchAgent: ${PLIST_DEST}"
    fi

    if crontab -l 2>/dev/null | grep -Fq "${BACKUP_SCRIPT}"; then
        (crontab -l 2>/dev/null | grep -Fv "${BACKUP_SCRIPT}") | crontab - 2>/dev/null || true
        echo "Removed cron entry."
    fi

    echo "Uninstall completed."
}

case "${1:-help}" in
    install)
        install_launchagent
        ;;
    install-cron)
        install_cron
        ;;
    check-plugins)
        if [ -x "${SCRIPT_DIR}/install.sh" ]; then
            "${SCRIPT_DIR}/install.sh" --check-plugins
        else
            echo "Error: install.sh not found." >&2
            exit 1
        fi
        ;;
    test)
        run_test
        ;;
    status)
        check_status
        ;;
    uninstall)
        uninstall
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1" >&2
        show_help
        exit 1
        ;;
esac
