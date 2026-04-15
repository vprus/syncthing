#!/bin/bash
set -euo pipefail

# Install Syncthing as a macOS user LaunchAgent.
# Builds from source if needed, installs binary and launchd plist,
# and starts the service using modern launchctl commands.

LABEL="net.syncthing.syncthing"
PREFIX="${HOME}/local"
BINDIR="${PREFIX}/bin"
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_FILE="${PLIST_DIR}/syncthing.plist"
LOG_DIR="${HOME}/Library/Logs"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--prefix <path>] [--no-build] [--no-start]

Options:
  --prefix <path>   Install prefix (default: ~/local)
  --no-build        Skip building; use existing binary from repo bin/
  --no-start        Install files but do not start the service
  -h, --help        Show this help
EOF
}

main() {
    local do_build=true
    local do_start=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)  PREFIX="$2"; BINDIR="${PREFIX}/bin"; shift 2 ;;
            --no-build) do_build=false; shift ;;
            --no-start) do_start=false; shift ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo "Error: this script is for macOS only." >&2
        exit 1
    fi

    local src_binary="${REPO_DIR}/syncthing"

    if $do_build; then
        echo "==> Building syncthing..."
        (cd "${REPO_DIR}" && go run build.go build)
    fi

    if [[ ! -x "${src_binary}" ]]; then
        echo "Error: syncthing binary not found at ${src_binary}" >&2
        echo "       Run 'go run build.go build' first or omit --no-build." >&2
        exit 1
    fi

    # Stop existing service if loaded
    if launchctl print "gui/$(id -u)/${LABEL}" &>/dev/null; then
        echo "==> Stopping existing Syncthing service..."
        launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
        sleep 1
    fi

    echo "==> Installing binary to ${BINDIR}/syncthing"
    mkdir -p "${BINDIR}"
    cp "${src_binary}" "${BINDIR}/syncthing"
    chmod 755 "${BINDIR}/syncthing"

    echo "==> Installing LaunchAgent plist"
    mkdir -p "${PLIST_DIR}"
    generate_plist > "${PLIST_FILE}"

    if $do_start; then
        echo "==> Starting Syncthing service..."
        launchctl bootstrap "gui/$(id -u)" "${PLIST_FILE}"
    fi

    echo ""
    echo "Syncthing installed successfully."
    echo "  Binary:   ${BINDIR}/syncthing"
    echo "  Plist:    ${PLIST_FILE}"
    echo "  Logs:     ${LOG_DIR}/Syncthing.log"
    echo "  Errors:   ${LOG_DIR}/Syncthing-Errors.log"
    echo "  Web UI:   http://127.0.0.1:8384"
    echo ""
    echo "Syncthing will start automatically on login."
    echo "  Stop:     launchctl bootout gui/$(id -u)/${LABEL}"
    echo "  Restart:  launchctl kickstart -k gui/$(id -u)/${LABEL}"
    echo "  Status:   launchctl print gui/$(id -u)/${LABEL}"
}

generate_plist() {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${BINDIR}/syncthing</string>
        <string>--no-browser</string>
        <string>--no-restart</string>
    </array>

    <key>KeepAlive</key>
    <true/>

    <key>LowPriorityIO</key>
    <true/>

    <key>ProcessType</key>
    <string>Background</string>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/Syncthing.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/Syncthing-Errors.log</string>
</dict>
</plist>
EOF
}

main "$@"
