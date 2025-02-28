#!/usr/bin/env bash

SOURCE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)

# source package metadata
source "${SOURCE_DIR}/doc/package.conf"

# print help message
function print_help() {
    echo "Usage: ${0} [options]"; echo
    echo "OPTIONS:"
    echo "  -h, --help                   print help message"
    echo "  -i, --install-prefix <path>  specify an installation prefix"
    echo "  -l, --link                   perform a symlink installation"
    echo "  -u, --uninstall              uninstall the service menu"
    echo "  -v, --version                return ${__name__} version"; echo
    echo "Report bugs to ${__bugs__}"
}

# get optional arguments
while [ ${#} -gt 0 ]; do
    case "${1}" in
        -h|--help)
            print_help
            exit 0
            ;;
        -i|--install-prefix)
            if [ -z "${2}" ]; then
                echo "ERROR: Please specify an installation prefix"
                exit 1
            fi
            INSTALL_PFX="${2}"
            shift
            ;;
        -l|--link)
            LINK_INSTALL=1
            ;;
        -u|--uninstall)
            UNINSTALL_APP=1
            ;;
        -v|--version)
            echo "${__name__}: ${__version__}"
            exit 0
            ;;
        *)
            echo "ERROR: Invalid argument (${1})"
            exit 1
            ;;
    esac
    shift
done

# ============================================================================================================================

function install() {
    local installation_files=("${@}")
    local i source target required_directories d
    if [ "${#installation_files[@]}" -gt 0 ]; then
        echo "Installing ${__name__}..."
        # check for source installation files before proceeding
        for i in "${installation_files[@]}"; do
            IFS='|' read -r source target <<< "${i}"
            if [ ! -f "${SOURCE_DIR}/${source}" ]; then
                echo "ERROR: Required file not found (${source})"; exit 1
            fi
        done
        # populate required directories
        for i in "${installation_files[@]}"; do
            IFS='|' read -r source target <<< "${i}"
            # add directory to array if not already
            if [[ ! " ${required_directories[@]} " =~ " ${target%/*} " ]]; then
                required_directories+=("${target%/*}")
            fi
        done
        # create required directories
        for d in "${required_directories[@]}"; do
            echo "Creating directory ${d}"
            mkdir -p "${d}"
        done
        # install source files
        for i in "${installation_files[@]}"; do
            IFS='|' read -r source target <<< "${i}"
            echo "Installing ${source} to ${target}"
            if [ "${LINK_INSTALL}" != 1 ] || [[ "${source}" =~ ^(config|log)/ ]]; then
                cp -i "${SOURCE_DIR}/${source}" "${target}"
            else
                ln -s "$(realpath "${SOURCE_DIR}/${source}")" "${target}"
            fi
        done
    fi
}

function uninstall() {
    local installation_files=("${@}")
    local i source target removed_targets
    if [ "${#installation_files[@]}" -gt 0 ]; then
        echo "Uninstalling ${__name__}..."
        # remove installed files
        for i in "${installation_files[@]}"; do
            IFS='|' read -r source target <<< "${i}"
            if [[ ! " ${removed_targets[@]} " =~ " ${target} " ]]; then
                echo "Removing ${target}"
                rm -f "${target}" 2>/dev/null || rm -rf "${target}" 2>/dev/null && removed_targets+=("${target}")
            fi
        done
    fi
}

# ============================================================================================================================

# set default options
INSTALL_PFX=$(realpath "${INSTALL_PFX:-"${HOME}/.local"}") || exit 1

# installation files
installation_files=(
    "bin/main.sh|${INSTALL_PFX}/bin/${__name__}"
)

# ============================================================================================================================

# run installer
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ "${UNINSTALL_APP}" == "1" ]; then
        uninstall "${installation_files[@]}"
    else
        install "${installation_files[@]}"
    fi
fi
