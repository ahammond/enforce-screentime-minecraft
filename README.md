# Enforce Screen Time for Minecraft Java Edition

> Make Minecraft follow the same Screen Time rules as other apps on macOS

## The Problem

Minecraft Java Edition runs in the Java Virtual Machine and completely bypasses macOS Screen Time parental controls. While other apps respect downtime and app limits, Minecraft keeps running, making Screen Time settings ineffective.

## The Solution

This tool enforces your Screen Time settings by automatically terminating Minecraft at your configured downtime. It's:

- **Simple**: One-line installation
- **Flexible**: Configurable shutdown time
- **Safe**: Graceful termination allows Minecraft to save
- **Transparent**: All actions logged to system log
- **Idempotent**: Update anytime by re-running installer

## Quick Start

Install with default time (7:05 PM):

```bash
curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash
```

Install with custom time (like 8:30 PM):

```bash
curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash -s -- --time=20:30
```

That's it! Minecraft will now be terminated at your specified time, daily. Screentime rules should prevent it being restarted.

## Features

- ✅ Automatic daily enforcement at configured time
- ✅ Graceful termination (gives Minecraft time to save)
- ✅ Integrated with macOS unified logging
- ✅ Idempotent installer - run multiple times safely
- ✅ Easy time changes - just re-run installer
- ✅ No impact on other applications

## How It Works

1. At the scheduled time daily, the system runs the enforcement script
2. Script checks if current time is within enforcement window (6 hours after scheduled time)
3. If within window, searches for Minecraft Java processes
4. Sends graceful termination signal (TERM)
5. Waits 2 seconds for Minecraft to save
6. Forces termination if still running (KILL)
7. Logs all actions to system log

This makes Minecraft follow the same Screen Time rules as native macOS apps.

### Handling Sleep/Wake

If your laptop is asleep at the scheduled time (e.g., 7:05 PM), the enforcement will automatically run when the system wakes up, **but only if you're still within the 6-hour enforcement window**. This means:

- ✅ Laptop wakes at 8:00 PM → Minecraft terminated (within window)
- ✅ Laptop wakes at 11:00 PM → Minecraft terminated (within window)
- ❌ Laptop wakes at 9:00 AM next day → Minecraft NOT terminated (outside window)

This prevents unwanted shutdowns the next morning while still catching violations on late wakeups.

Unfortunately I haven't found a way to access the native screentime API
to know what time to enforce. If you know how, please let me know by opening a GH issue.

## Updating

### Change Shutdown Time

Want to change when Minecraft shuts down? Just run the installer again with a new time (like 9:00 PM):

```bash
curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash -s -- --time=21:00
```

### Update to Latest Version

Get the latest improvements by running the installer again:

```bash
curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash
```

This will preserve the configured shutdown time.

## Testing

Test the script manually before waiting for scheduled time:

```bash
# Start Minecraft, then run:
sudo /usr/local/bin/enforce-screentime-minecraft.sh
```

View logs:

```bash
/usr/bin/log show --predicate 'eventMessage contains "screentime-enforce"' --last 1h --info --style compact
```

## Temporarily Disable

Need to allow extra time one evening?

```bash
# Disable
sudo launchctl bootout system /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist

# Re-enable
sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist
```

but... honestly? Just wait until after the shutdown time, grant the additional screentime
using the native controls and then restart Minecraft.

## Uninstall

Want to remove the Screen Time enforcement? Run this one command:

```bash
curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/uninstall.sh | sudo bash
```

This completely removes the enforcement from your system, and Minecraft will no longer be automatically shut down.

## Documentation

- [Installation Guide](INSTALLATION.md) - Detailed installation and configuration
- [Troubleshooting](INSTALLATION.md#troubleshooting) - Common issues and solutions

## Requirements

- MacOS
- Administrator (sudo) access
- Minecraft Java Edition

## Why This is Needed

MacOS Screen Time is designed for native apps and cannot control Java applications running in the JVM.
The Minecraft launcher is a native app that Screen Time can see, but it only runs briefly before handing off to the Java process.
Once the Java process is running, Screen Time has no visibility or control over it.

This tool bridges that gap by finding Minecraft processes and enforcing your Screen Time settings.

## Contributing

Issues and pull requests welcome! This tool was created to help parents enforce healthy screen time boundaries for their children.

## License

MIT License - See [LICENSE](LICENSE) file for details

## Acknowledgments

Built for parents struggling with Minecraft bypassing Screen Time controls. Inspired by the many frustrated parents in Apple Support Communities and forums looking for a solution.
Big love to Notch and Mojang.
