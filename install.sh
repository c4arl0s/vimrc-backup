#!/usr/bin/env bash
# ==============================================================================
# install.sh
#
# Copies the repository's vimrc configuration to ~/.vimrc on any macOS system.
# Safely preserves any existing ~/.vimrc with a timestamped backup copy.
# Verifies if declared plugins are already installed or missing.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_VIMRC="${SCRIPT_DIR}/vimrc"
TARGET_VIMRC="${HOME}/.vimrc"

BACKUP=true
FORCE=false
INSTALL_PLUG=false
INSTALL_PLUGINS=false
ONLY_CHECK_PLUGINS=false

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

Installs the repository's vimrc into your home directory as ~/.vimrc on macOS,
and verifies the status of declared plugins.

Options:
  -f, --force          Overwrite ~/.vimrc without confirmation prompts
  --no-backup          Do not create a backup copy of an existing ~/.vimrc
  --plug               Automatically download and install vim-plug if missing
  --install-plugins    Automatically install missing plugins using 'vim +PlugInstall +qall'
  -c, --check-plugins  Only verify if declared plugins are installed/missing (no files modified)
  -h, --help           Display this help message and exit

Examples:
  ./install.sh                     # Standard install & plugin verification
  ./install.sh --check-plugins     # Verify plugin installation status only
  ./install.sh --plug              # Install vimrc and set up vim-plug
  ./install.sh --install-plugins   # Install vimrc, vim-plug, and fetch missing plugins
  ./install.sh --force             # Overwrite existing ~/.vimrc directly
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
        --install-plugins)
            INSTALL_PLUG=true
            INSTALL_PLUGINS=true
            shift
            ;;
        -c|--check-plugins)
            ONLY_CHECK_PLUGINS=true
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
# Plugin Verification Logic
# ------------------------------------------------------------------------------
verify_plugins() {
    local target_file="$1"

    if [[ ! -f "${target_file}" ]]; then
        log_error "Cannot verify plugins: ${target_file} does not exist."
        return 1
    fi

    # Determine plugged directory (default ~/.vim/plugged, or custom if plug#begin specifies)
    local plug_dir="${HOME}/.vim/plugged"
    if grep -qE "^[[:space:]]*call[[:space:]]+plug#begin\(" "${target_file}"; then
        local custom_dir
        custom_dir="$(grep -E "^[[:space:]]*call[[:space:]]+plug#begin\(" "${target_file}" | sed -E "s/^[[:space:]]*call[[:space:]]+plug#begin\(['\"]([^'\"]+)['\"]\).*/\1/" | head -n 1)"
        if [[ -n "${custom_dir}" && "${custom_dir}" != *"plug#begin"* ]]; then
            if [[ "${custom_dir}" == ~* ]]; then
                plug_dir="${HOME}${custom_dir#\~}"
            elif [[ "${custom_dir}" != /* ]]; then
                plug_dir="${HOME}/.vim/${custom_dir}"
            else
                plug_dir="${custom_dir}"
            fi
        fi
    fi

    echo ""
    log_info "Verifying plugins declared in ${target_file}..."
    echo "Plugin storage directory: ${plug_dir}"
    echo "------------------------------------------------------------"

    local installed_count=0
    local missing_count=0
    local missing_plugins=()

    # Read each plugin declaration line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Strip leading whitespace
        local trimmed="${line#"${line%%[![:space:]]*}"}"
        # Skip commented lines (starting with " or #)
        if [[ "${trimmed}" =~ ^[\"\#] ]]; then
            continue
        fi

        # Extract plugin repo/name from quotes after Plug
        local plugin
        plugin="$(echo "${line}" | sed -E "s/^[[:space:]]*Plug[[:space:]]+['\"]([^'\",]+)['\"].*/\1/")"
        [[ -z "${plugin}" ]] && continue

        # Determine plugin directory name in plugged directory
        local plugin_folder=""
        if echo "${line}" | grep -qE "['\"]as['\"][[:space:]]*:[[:space:]]*['\"]"; then
            plugin_folder="$(echo "${line}" | sed -E "s/.*['\"]as['\"][[:space:]]*:[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")"
            plugin_folder="${plug_dir}/${plugin_folder}"
        elif echo "${line}" | grep -qE "['\"]dir['\"][[:space:]]*:[[:space:]]*['\"]"; then
            local custom_pdir
            custom_pdir="$(echo "${line}" | sed -E "s/.*['\"]dir['\"][[:space:]]*:[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")"
            if [[ "${custom_pdir}" == ~* ]]; then
                plugin_folder="${HOME}${custom_pdir#\~}"
            elif [[ "${custom_pdir}" != /* ]]; then
                plugin_folder="${plug_dir}/${custom_pdir}"
            else
                plugin_folder="${custom_pdir}"
            fi
        else
            local plugin_base
            plugin_base="$(basename "${plugin}" .git)"
            plugin_folder="${plug_dir}/${plugin_base}"
        fi

        # Check if the directory exists and contains files
        if [[ -d "${plugin_folder}" ]] && [[ -n "$(ls -A "${plugin_folder}" 2>/dev/null)" ]]; then
            echo -e "  \033[1;32m✔ [INSTALLED]\033[0m ${plugin} \033[2m(${plugin_folder})\033[0m"
            installed_count=$((installed_count + 1))
        else
            echo -e "  \033[1;31m✖ [MISSING]\033[0m   ${plugin} \033[2m(expected at ${plugin_folder})\033[0m"
            missing_count=$((missing_count + 1))
            missing_plugins+=("${plugin}")
        fi
    done < <(grep -E "^[[:space:]]*Plug[[:space:]]+['\"][^'\"]+['\"]" "${target_file}" || true)

    local total_count=$((installed_count + missing_count))
    echo "------------------------------------------------------------"
    if [[ ${total_count} -eq 0 ]]; then
        log_info "No plugins declared in ${target_file}."
        return 0
    fi

    if [[ ${missing_count} -eq 0 ]]; then
        echo -e "Summary: \033[1;32m${installed_count} installed\033[0m, \033[1;32m0 missing\033[0m (out of ${total_count} total)"
        log_success "All declared plugins are properly installed!"
        return 0
    else
        echo -e "Summary: \033[1;32m${installed_count} installed\033[0m, \033[1;31m${missing_count} missing\033[0m (out of ${total_count} total)"
        echo ""
        log_warn "Missing plugins detected!"

        if [[ "${INSTALL_PLUGINS}" == true ]]; then
            log_info "Running 'vim +PlugInstall +qall' to download and install missing plugins..."
            if command -v vim >/dev/null 2>&1; then
                vim +PlugInstall +qall || true
                echo ""
                log_success "Plugin installation command finished."
            else
                log_error "vim is not found in PATH."
            fi
        else
            echo "To install missing plugins, run:"
            echo "    vim +PlugInstall +qall"
            echo "Or rerun this installer with:"
            echo "    ./install.sh --install-plugins"
        fi
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Standalone Check Only Mode
# ------------------------------------------------------------------------------
if [[ "${ONLY_CHECK_PLUGINS}" == true ]]; then
    target_to_check="${TARGET_VIMRC}"
    if [[ ! -f "${target_to_check}" ]]; then
        target_to_check="${SOURCE_VIMRC}"
    fi
    verify_plugins "${target_to_check}" || true
    exit 0
fi

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
    log_warn "This installer is designed for macOS. Operating system detected: $(uname -s)"
fi

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
    rm -f "${TARGET_VIMRC}"
    cp "${SOURCE_VIMRC}" "${TARGET_VIMRC}"
    log_success "Installed ~/.vimrc (replaced existing symlink)."
else
    cp "${SOURCE_VIMRC}" "${TARGET_VIMRC}"
    log_success "Successfully installed ~/.vimrc."
fi

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

# ------------------------------------------------------------------------------
# Verify Plugins
# ------------------------------------------------------------------------------
verify_plugins "${TARGET_VIMRC}" || true

echo ""
log_success "Installation complete!"
echo "You can launch vim now with: vim"
