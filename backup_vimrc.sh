#!/usr/bin/env bash
# ==============================================================================
# backup_vimrc.sh
#
# Automated backup script for ~/.vimrc.
# - Compares ~/.vimrc against the tracked vimrc in this repository.
# - Creates a timestamped local backup snapshot.
# - Commits and pushes changes to the remote Git repository.
# - Handles network reconnect delays gracefully when run on wake-up.
# ==============================================================================

set -euo pipefail

# Ensure standard tools and Homebrew binaries are in PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}"
SOURCE_VIMRC="${HOME}/.vimrc"
REPO_VIMRC="${REPO_DIR}/vimrc"
BACKUP_DIR="${HOME}/.vimrc_backups"
LOG_DIR="${HOME}/Library/Logs"
LOG_FILE="${LOG_DIR}/vimrc-backup.log"

# Ensure log directory and log file are writable; fallback to repo directory if not
if ! mkdir -p "${LOG_DIR}" 2>/dev/null || ! touch "${LOG_FILE}" 2>/dev/null; then
    LOG_FILE="${REPO_DIR}/vimrc-backup.log"
    touch "${LOG_FILE}" 2>/dev/null || true
fi

# Ensure backup directory is writable; fallback to repo directory if not
if ! mkdir -p "${BACKUP_DIR}" 2>/dev/null; then
    BACKUP_DIR="${REPO_DIR}/.backups"
    mkdir -p "${BACKUP_DIR}" 2>/dev/null || true
fi

# Default flags
FORCE=false
QUIET=false
SHOW_NOTIFICATIONS=true
ENABLE_JARVIS=true
JARVIS_VOICE="Daniel"
JARVIS_RATE=165

# ------------------------------------------------------------------------------
# Logging, Notification & JARVIS Voice Helpers
# ------------------------------------------------------------------------------
log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local message="[${timestamp}] $*"
    if [ "${QUIET}" = false ]; then
        echo "${message}"
    fi
    if [ -w "${LOG_FILE}" ]; then
        echo "${message}" >> "${LOG_FILE}"
    fi
}

get_greeting() {
    local hour
    hour=$(date +%H)
    # Remove leading zero if present
    hour=$((10#$hour))
    if [ "${hour}" -ge 4 ] && [ "${hour}" -lt 12 ]; then
        echo "Good morning, sir."
    elif [ "${hour}" -ge 12 ] && [ "${hour}" -lt 18 ]; then
        echo "Good afternoon, sir."
    else
        echo "Good evening, sir."
    fi
}

speak_jarvis() {
    local text="$1"
    if [ "${ENABLE_JARVIS}" = true ] && command -v say >/dev/null 2>&1; then
        # Check if the requested voice is installed
        local voice_args=()
        if say -v '?' 2>/dev/null | grep -qi "^${JARVIS_VOICE} "; then
            voice_args=(-v "${JARVIS_VOICE}")
        fi
        log "JARVIS Voice announcement: '${text}'"
        # Run synchronously so launchd/subshell does not kill speech before it completes
        say "${voice_args[@]}" -r "${JARVIS_RATE}" "${text}" 2>> "${LOG_FILE}" || true
    fi
}

notify() {
    local message="$1"
    local subtitle="${2:-}"
    local voice_text="${3:-}"

    # Visual notification banner
    if [ "${SHOW_NOTIFICATIONS}" = true ] && command -v osascript >/dev/null 2>&1; then
        if [ -n "${subtitle}" ]; then
            osascript -e "display notification \"${message}\" with title \"Vimrc Backup\" subtitle \"${subtitle}\" sound name \"default\"" 2>/dev/null || true
        else
            osascript -e "display notification \"${message}\" with title \"Vimrc Backup\" sound name \"default\"" 2>/dev/null || true
        fi
    fi

    # JARVIS voice audio
    if [ -n "${voice_text}" ]; then
        speak_jarvis "${voice_text}"
    fi
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -f, --force          Force backup and push even if no content differences are detected
  -q, --quiet          Suppress stdout messages (logs are still written to ${LOG_FILE})
  --no-notify          Disable macOS desktop banner notifications
  --no-voice           Disable JARVIS voice messages
  --voice <name>       Set speech voice (default: Daniel)
  -h, --help           Display this help message and exit

Description:
  Verifies if ~/.vimrc has changed compared to the git-tracked vimrc file.
  If changes exist (or unpushed commits exist), updates the repository,
  creates a commit, and pushes to remote.
  Displays a macOS notification banner and reproduces a JARVIS voice message.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
            FORCE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --no-notify)
            SHOW_NOTIFICATIONS=false
            shift
            ;;
        --no-voice)
            ENABLE_JARVIS=false
            shift
            ;;
        --voice)
            JARVIS_VOICE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Pre-checks
# ------------------------------------------------------------------------------
if [ ! -f "${SOURCE_VIMRC}" ]; then
    log "ERROR: Source file ${SOURCE_VIMRC} does not exist. Nothing to backup."
    exit 1
fi

cd "${REPO_DIR}"

# Ensure this is a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "ERROR: ${REPO_DIR} is not a valid git repository."
    exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Function to push with retry (useful when running right after wake-up while Wi-Fi reconnects)
push_with_retry() {
    local max_attempts=5
    local delay=4
    local attempt=1

    while [ ${attempt} -le ${max_attempts} ]; do
        log "Attempting git push origin ${CURRENT_BRANCH} (attempt ${attempt}/${max_attempts})..."
        if git push origin "${CURRENT_BRANCH}" >> "${LOG_FILE}" 2>&1; then
            log "SUCCESS: Changes successfully pushed to origin/${CURRENT_BRANCH}."
            return 0
        fi

        if [ ${attempt} -lt ${max_attempts} ]; then
            log "Push attempt ${attempt} failed (network may still be connecting). Retrying in ${delay}s..."
            sleep "${delay}"
        fi
        attempt=$((attempt + 1))
    done

    log "WARNING: Could not push to remote after ${max_attempts} attempts. Changes remain committed locally and will be pushed on the next run."
    return 1
}

# ------------------------------------------------------------------------------
# Check for Changes
# ------------------------------------------------------------------------------
has_changes=false

if [ ! -f "${REPO_VIMRC}" ] || ! cmp -s "${SOURCE_VIMRC}" "${REPO_VIMRC}"; then
    has_changes=true
fi

if [ "${has_changes}" = true ] || [ "${FORCE}" = true ]; then
    log "Changes detected in ${SOURCE_VIMRC} (or --force requested)."

    # 1. Update repo file
    cp "${SOURCE_VIMRC}" "${REPO_VIMRC}"

    # 2. Save a local timestamped snapshot
    mkdir -p "${BACKUP_DIR}" 2>/dev/null || true
    TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
    SNAPSHOT_PATH="${BACKUP_DIR}/vimrc_${TIMESTAMP}"
    cp "${SOURCE_VIMRC}" "${SNAPSHOT_PATH}" 2>/dev/null || true
    log "Created local backup snapshot at ${SNAPSHOT_PATH}."

    # 3. Git commit
    git add "${REPO_VIMRC}"
    if ! git diff --cached --quiet; then
        COMMIT_MSG="Auto backup vimrc: $(date '+%Y-%m-%d %H:%M:%S')"
        git commit -m "${COMMIT_MSG}" >> "${LOG_FILE}" 2>&1
        log "Committed new changes: '${COMMIT_MSG}'."

        # 4. Push to remote
        GREETING="$(get_greeting)"
        if push_with_retry; then
            notify "New changes backed up and pushed to GitHub." "Synced to Remote" \
                   "${GREETING} New modifications detected in your vim configuration. Changes have been committed and pushed to GitHub."
        else
            notify "Changes saved locally. Push deferred (offline)." "Offline Backup" \
                   "Sir, your vim configuration has been backed up locally. Network connection is currently offline; remote push will resume shortly."
        fi
    else
        log "No git changes after staging. Working tree is clean."
        GREETING="$(get_greeting)"
        notify "Checked: ~/.vimrc is up to date." "No Changes" \
               "${GREETING} Vim configuration verified. All systems are up to date."
    fi

else
    log "No changes detected between ${SOURCE_VIMRC} and repository."

    # Check if there are any unpushed commits from an earlier offline run
    synced_unpushed=false
    if git rev-parse --verify "@{u}" >/dev/null 2>&1; then
        UNPUSHED_COUNT="$(git rev-list @{u}..HEAD --count 2>/dev/null || echo 0)"
        if [ "${UNPUSHED_COUNT}" -gt 0 ]; then
            log "Found ${UNPUSHED_COUNT} unpushed commit(s) from previous run. Pushing now..."
            if push_with_retry; then
                GREETING="$(get_greeting)"
                notify "Synced ${UNPUSHED_COUNT} previously unpushed commit(s) to GitHub." "Synced to Remote" \
                       "${GREETING} Pending vim commits have now been pushed to the remote repository."
                synced_unpushed=true
            fi
        fi
    fi

    if [ "${synced_unpushed}" = false ]; then
        GREETING="$(get_greeting)"
        notify "Checked: ~/.vimrc is up to date." "No Changes" \
               "${GREETING} Vim configuration verified. All systems are up to date."
    fi
fi

log "Backup check completed."
exit 0
