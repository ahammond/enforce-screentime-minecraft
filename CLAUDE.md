# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS-specific tool that enforces Screen Time parental controls for Minecraft Java Edition. Minecraft runs in a JVM and bypasses native Screen Time controls, so this tool uses a scheduled launchd daemon to terminate Minecraft processes at a configured time.

## Key Components

1. **enforce-screentime-minecraft.sh** - The core enforcement script that finds and terminates Minecraft Java processes
2. **com.user.enforce-screentime-minecraft.plist** - LaunchDaemon configuration with time placeholders (`__HOUR__`, `__MINUTE__`)
3. **install.sh** - Idempotent installer that downloads from GitHub, configures time, and loads the daemon
4. **uninstall.sh** - Complete removal script

## Installation Paths

- Script: `/usr/local/bin/enforce-screentime-minecraft.sh`
- LaunchDaemon plist: `/Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist`

## Time Configuration

The plist template uses `__HOUR__` and `__MINUTE__` placeholders that are replaced by the installer using `sed`. Default is 19:05 (7:05 PM). The installer preserves existing times when updating unless `--time=HH:MM` is explicitly provided.

## Testing & Debugging

**Test the enforcement script manually:**
```bash
sudo /usr/local/bin/enforce-screentime-minecraft.sh
```

**View logs (all actions use macOS unified logging with tag "screentime-enforce"):**
```bash
log show --predicate 'eventMessage contains "screentime-enforce"' --last 1h --style compact
log stream --predicate 'eventMessage contains "screentime-enforce"'
```

**Check if daemon is loaded:**
```bash
sudo launchctl list | grep enforce-screentime-minecraft
```

**Verify current configured time:**
```bash
defaults read /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist StartCalendarInterval
```

## Installer Design

The installer is **idempotent** - it can be run multiple times safely:
- Preserves existing shutdown time unless `--time=HH:MM` is specified
- Unloads daemon before updating plist, reloads after
- Downloads latest version from GitHub using `$GITHUB_RAW_BASE` variable (defaults to main branch)
- Validates time format and ranges (hour: 0-23, minute: 0-59)

## Process Detection

The enforcement script finds Minecraft using:
```bash
ps aux | grep -i '[j]ava.*minecraft' | awk '{print $2}'
```

The bracket trick `[j]ava` prevents grep from matching itself.

## Termination Flow

1. Send SIGTERM (graceful termination)
2. Wait `GRACE_PERIOD` seconds (default: 2)
3. Check if still running
4. Send SIGKILL if needed (force termination)

This allows Minecraft to save before forceful shutdown.

## Sleep/Wake Handling

The tool handles the laptop being asleep at enforcement time through two mechanisms:

1. **StartCalendarInterval automatic catch-up**: When the system is asleep at the scheduled time, launchd automatically runs the job once when the system wakes up (multiple missed intervals are coalesced into one execution).

2. **Enforcement window**: The script includes a time-check to only enforce within `ENFORCEMENT_WINDOW_HOURS` (default: 6 hours) after the scheduled time. This prevents unwanted terminations if the laptop wakes the next morning.

**Example scenario:**
- Scheduled time: 19:05 (7:05 PM)
- Enforcement window: 19:05 - 01:05 (next day)
- Laptop sleeps at 18:00, wakes at 09:00 next day
- launchd triggers the script (missed execution)
- Script checks current time (09:00) is outside window → exits without terminating Minecraft

The enforcement window prevents false positives while still catching legitimate violations within a reasonable timeframe (e.g., if laptop wakes at 20:00, Minecraft should still be terminated).

## Common Development Tasks

When modifying time-related code, remember:
- 24-hour format for internal storage/processing
- 12-hour format for user-facing display messages
- Both `--time=HH:MM` and separate `--hour`/`--minute` flags are supported

When modifying the plist:
- Keep `__HOUR__` and `__MINUTE__` placeholders intact
- The installer uses `sed -i ''` (BSD sed on macOS, not GNU sed)
- Always set ownership to `root:wheel` and permissions to `644`

When modifying logging:
- Use `logger -t "$SCRIPT_NAME"` for unified logging
- Use `-p user.notice` for info, `-p user.error` for errors
- Tag is "screentime-enforce" - users search logs with this
