# Enforce Screen Time for Minecraft Java Edition

Minecraft Java Edition runs in the Java Virtual Machine and bypasses macOS Screen Time parental controls. This solution enforces your Screen Time downtime settings by terminating Minecraft at the configured time.

## What This Does

- Runs automatically at your specified time (default: 7:05pm) daily
- Finds Minecraft Java processes and terminates them
- Allows Minecraft to save gracefully before forcing termination
- Logs all actions to macOS system log
- No impact on other applications

## Quick Install (Recommended)

Install with default time (7:05 PM):

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | sudo bash
```

Install with custom time (e.g., 8:30 PM):

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | sudo bash -s -- --time=20:30
```

That's it! The installer will:
- Download the latest version
- Install the enforcement script
- Configure the shutdown time
- Set up automatic daily execution
- Verify everything works

## Updating

### Change Shutdown Time

Simply re-run the installer with a new time:

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | sudo bash -s -- --time=21:00
```

The installer is idempotent - you can run it as many times as you want.

### Update to Latest Version

Re-run the installer to get bug fixes and improvements:

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | sudo bash
```

## Testing

### Test the Script Manually

Before waiting until shutdown time, test that the script works:

```bash
# Start Minecraft first, then run:
sudo /usr/local/bin/enforce-screentime-minecraft.sh

# Check if Minecraft was terminated
ps aux | grep minecraft
```

### View Logs

Check the system log to see enforcement actions:

```bash
# View recent enforcement logs
log show --predicate 'eventMessage contains "screentime-enforce"' --last 1h --style compact

# Stream logs in real-time (useful for testing)
log stream --predicate 'eventMessage contains "screentime-enforce"'
```

Or use Console.app:
1. Open Console.app
2. Search for "screentime-enforce"
3. View all enforcement actions

## Advanced Usage

### Temporarily Disabling

If you need to allow extended play time for one day:

```bash
# Disable enforcement
sudo launchctl bootout system /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist

# Re-enable enforcement (will run at next scheduled time)
sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist
```

### Check Current Configuration

View the current shutdown time:

```bash
defaults read /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist StartCalendarInterval
```

### Verify Installation Status

Check if the enforcement is active:

```bash
sudo launchctl list | grep enforce-screentime-minecraft
```

You should see output like:
```
-	0	com.user.enforce-screentime-minecraft
```

## Manual Installation

If you prefer not to use the automated installer:

### Step 1: Download Files

```bash
cd /tmp
curl -fsSL -O https://raw.githubusercontent.com/USER/REPO/main/enforce-screentime-minecraft.sh
curl -fsSL -O https://raw.githubusercontent.com/USER/REPO/main/com.user.enforce-screentime-minecraft.plist
```

### Step 2: Edit the Plist (Optional)

If you want a different time than 7:05 PM, edit the plist:

```bash
# Edit the hour (19 = 7 PM, 20 = 8 PM, etc.)
sed -i '' 's/__HOUR__/20/' com.user.enforce-screentime-minecraft.plist

# Edit the minute
sed -i '' 's/__MINUTE__/30/' com.user.enforce-screentime-minecraft.plist
```

### Step 3: Install

```bash
sudo cp enforce-screentime-minecraft.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/enforce-screentime-minecraft.sh
sudo cp com.user.enforce-screentime-minecraft.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist
sudo chmod 644 /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist
```

## Uninstallation

To completely remove Screen Time enforcement:

```bash
# Unload the daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist

# Remove files
sudo rm /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist
sudo rm /usr/local/bin/enforce-screentime-minecraft.sh
```

## Troubleshooting

**Minecraft isn't being terminated:**
1. Check if the daemon is loaded: `sudo launchctl list | grep enforce-screentime`
   - If not listed, manually load it: `sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist`
2. Test the script manually: `sudo /usr/local/bin/enforce-screentime-minecraft.sh`
3. Check logs: `log show --predicate 'eventMessage contains "screentime-enforce"' --last 1d --style compact`

**Installer fails:**
- Make sure you're running it with `sudo`
- Check your internet connection
- Verify the GitHub URL is correct

**Want to test before the scheduled time:**
- Run the script manually: `sudo /usr/local/bin/enforce-screentime-minecraft.sh`
- Or temporarily change the time to a few minutes in the future and reinstall

## How It Works

1. At the scheduled time daily, launchd runs the script
2. Script checks if current time is within enforcement window (6 hours after scheduled time)
3. If within window, searches for Java processes with "minecraft" in the command
4. Sends graceful termination signal (TERM)
5. Waits 2 seconds for Minecraft to save and exit
6. If still running, forces termination (KILL)
7. Logs all actions to system log

This makes Minecraft follow the same Screen Time rules as other apps on your child's computer.

### What Happens If The Laptop Is Asleep?

If the laptop is asleep at the enforcement time (e.g., 7:05 PM), the system automatically handles this:

- When the laptop wakes up, the enforcement script runs automatically
- **However**, the script only terminates Minecraft if you're still within the 6-hour enforcement window
- This prevents unwanted terminations if the laptop wakes the next morning

**Examples:**
- Scheduled time: 7:05 PM, Laptop wakes at 8:30 PM → ✅ Minecraft terminated
- Scheduled time: 7:05 PM, Laptop wakes at 12:00 AM → ✅ Minecraft terminated (still within 6h window)
- Scheduled time: 7:05 PM, Laptop wakes at 9:00 AM → ❌ Minecraft NOT terminated (outside 6h window)
