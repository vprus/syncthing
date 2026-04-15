#!/bin/bash
set -euo pipefail

# Uninstall Syncthing LaunchAgent and optionally remove the binary.

LABEL="net.syncthing.syncthing"
PREFIX="${HOME}/local"
BINDIR="${PREFIX}/bin"
PLIST_FILE="${HOME}/Library/LaunchAgents/syncthing.plist"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--prefix <path>] [--keep-binary] [--keep-config]

Options:
  --prefix <path>   Install prefix to remove binary from (default: ~/local)
  --keep-binary     Do not remove the syncthing binary
  --keep-config     (default) Configuration in ~/Library/Application Support/Syncthing
                    is always preserved; this flag is accepted for clarity
  -h, --help        Show this help
EOF
}

main() {
    local keep_binary=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)      PREFIX="$2"; BINDIR="${PREFIX}/bin"; shift 2 ;;
            --keep-binary) keep_binary=true; shift ;;
            --keep-config) shift ;;  # config is always kept
            -h|--help) usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo "Error: this script is for macOS only." >&2
        exit 1
    fi

    # Stop the service
    if launchctl print "gui/$(id -u)/${LABEL}" &>/dev/null; then
        echo "==> Stopping Syncthing service..."
        launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
        sleep 1
    else
        echo "==> Syncthing service is not loaded"
    fi

    # Remove plist
    if [[ -f "${PLIST_FILE}" ]]; then
        echo "==> Removing ${PLIST_FILE}"
        rm "${PLIST_FILE}"
    fi

    # Remove binary
    if ! $keep_binary && [[ -f "${BINDIR}/syncthing" ]]; then
        echo "==> Removing ${BINDIR}/syncthing"
        rm "${BINDIR}/syncthing"
    fi

    echo ""
    echo "Syncthing uninstalled."
    echo "  Configuration preserved in: ~/Library/Application Support/Syncthing"
    echo "  Logs preserved in:          ~/Library/Logs/Syncthing*.log"
}

main "$@"
