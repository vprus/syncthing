# Syncthing on macOS

Run Syncthing as a background LaunchAgent that starts automatically on login.

## Quick Install (from source)

```bash
./install.sh
```

This will:
- Build Syncthing (if not already built)
- Install the binary to `~/local/bin/syncthing`
- Install a LaunchAgent plist to `~/Library/LaunchAgents/`
- Start the service immediately
- Pass `--no-upgrade` so the installed binary is not replaced automatically

Options:

```
--prefix <path>   Install prefix (default: ~/local)
--no-build        Skip building; use existing binary from repo bin/
--no-start        Install files but do not start the service
```

## Uninstall

```bash
./uninstall.sh
```

Configuration in `~/Library/Application Support/Syncthing` is preserved.

## Managing the Service

```bash
# Stop
launchctl bootout gui/$(id -u)/net.syncthing.syncthing

# Start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/syncthing.plist

# Restart
launchctl kickstart -k gui/$(id -u)/net.syncthing.syncthing

# Status
launchctl print gui/$(id -u)/net.syncthing.syncthing
```

## Manual Setup

If you prefer not to use the install script:

1. Build syncthing: `go run build.go build` (from the repo root)
2. Copy the binary to `~/local/bin/syncthing`
3. Edit `syncthing.plist` — replace `USERNAME` with your macOS username
4. Copy it to `~/Library/LaunchAgents/syncthing.plist`
5. Run: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/syncthing.plist`

## Logs

- `~/Library/Logs/Syncthing.log` — standard output
- `~/Library/Logs/Syncthing-Errors.log` — errors and crashes
