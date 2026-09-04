#!/usr/bin/env bash
# ==============================================================================
# install.sh
#
# Copies the repository's vimrc configuration to ~/.vimrc on any macOS system.
# Safely preserves any existing ~/.vimrc with a timestamped backup copy.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_VIMRC="${SCRIPT_DIR}/vimrc"
TARGET_VIMRC="${HOME}/.vimrc"

BACKUP=true
FORCE=false
INSTALL_PLUG=false

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $*"
}

log_warn() {
    echo -e "\033[1;33m[WARNING]\033[0m $*"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Installs the repository's vimrc into your home directory as ~/.vimrc on macOS.

Options:
  -f, --force         Overwrite ~/.vimrc without confirmation prompts
  --no-backup         Do not create a backup copy of an existing ~/.vimrc
  --plug              Automatically download and install vim-plug if missing
  -h, --help          Display this help message and exit

Examples:
  ./install.sh                # Standard install (safely backs up existing ~/.vimrc)
  ./install.sh --plug         # Install vimrc and set up vim-plug
  ./install.sh --force        # Overwrite existing ~/.vimrc directly
EOF
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
            FORCE=true
            shift
            ;;
        --no-backup)
            BACKUP=false
            shift
            ;;
        --plug)
            INSTALL_PLUG=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
# macOS verification
if [[ "$(uname -s)" != "Darwin" ]]; then
    log_warn "This installer is designed for macOS. Operating system detected: $(uname -s)"
fi

# Source file check
if [[ ! -f "${SOURCE_VIMRC}" ]]; then
    log_error "Source vimrc file not found at: ${SOURCE_VIMRC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Installation Logic
# ------------------------------------------------------------------------------
if [[ -f "${TARGET_VIMRC}" ]]; then
    if cmp -s "${SOURCE_VIMRC}" "${TARGET_VIMRC}"; then
        log_info "${TARGET_VIMRC} is already identical to the repository version. No changes needed."
    else
        if [[ "${BACKUP}" == true ]]; then
            TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
            BACKUP_FILE="${TARGET_VIMRC}.backup.${TIMESTAMP}"
            cp "${TARGET_VIMRC}" "${BACKUP_FILE}"
            log_info "Existing ~/.vimrc backed up to: ${BACKUP_FILE}"
        fi

        cp "${SOURCE_VIMRC}" "${TARGET_VIMRC}"
        log_success "Updated ~/.vimrc with configuration from ${SOURCE_VIMRC}."
    fi
elif [[ -L "${TARGET_VIMRC}" ]]; then
    # In case ~/.vimrc is a broken symlink
    rm -f "${TARGET_VIMRC}"
    cp "${SOURCE_VIMRC}" "${TARGET_VIMRC}"
    log_success "Installed ~/.vimrc (replaced existing symlink)."
else
    cp "${SOURCE_VIMRC}" "${TARGET_VIMRC}"
    log_success "Successfully installed ~/.vimrc."
fi

# Ensure correct file permissions
chmod 644 "${TARGET_VIMRC}"

# ------------------------------------------------------------------------------
# Vim-Plug Check / Setup
# ------------------------------------------------------------------------------
VIM_PLUG_PATH="${HOME}/.vim/autoload/plug.vim"

if [[ "${INSTALL_PLUG}" == true ]]; then
    if [[ ! -f "${VIM_PLUG_PATH}" ]]; then
        log_info "Installing vim-plug..."
        if curl -fLo "${VIM_PLUG_PATH}" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
            log_success "Installed vim-plug at ${VIM_PLUG_PATH}."
        else
            log_warn "Failed to download vim-plug. Check internet connection."
        fi
    else
        log_info "vim-plug is already installed at ${VIM_PLUG_PATH}."
    fi
else
    if [[ ! -f "${VIM_PLUG_PATH}" ]] && grep -q "plug#begin" "${TARGET_VIMRC}"; then
        echo ""
        log_info "Tip: Your vimrc uses vim-plug plugins. To install vim-plug, run:"
        echo "      curl -fLo ~/.vim/autoload/plug.vim --create-dirs \\"
        echo "          https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
        echo "      Or rerun: ./install.sh --plug"
    fi
fi

echo ""
log_success "Installation complete!"
echo "You can launch vim now with: vim"
