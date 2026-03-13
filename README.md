# tasks (iOS Reminder App)

A lightweight iOS app for daily templates, today checklists, and local task reminders.

## Features

- Daily templates with weekday repeat rules (`Repeat on`)
- Today list with quick done toggle
- Local notifications for any task with `Reminder Time`
- Daily pending summary reminder
- Carry-over for unfinished temporary tasks, with `STALE` marker after 3+ days
- One-tap `Open Clock Site` for clock-related tasks

## Requirements

- macOS with Xcode (latest stable recommended)
- iPhone + USB cable (for best notification testing)
- Apple ID signed in to Xcode

## Run on Simulator

1. Clone:
   - `git clone git@github.com:vectorwei/task-reminder.git`
2. Open:
   - `clockreminder/clockreminder.xcodeproj`
3. Select an iPhone simulator.
4. Press `Cmd + R`.
5. Allow notification permission on first launch.

## Install on Your Own iPhone

1. Connect your iPhone to your Mac with a cable.
2. Unlock iPhone and tap **Trust This Computer** if prompted.
3. In Xcode, open `TARGETS` -> `clockreminder` -> `Signing & Capabilities`.
4. Turn on **Automatically manage signing**.
5. Select your Apple ID under **Team**.
6. Use a unique bundle identifier (example: `com.yourname.tasks`).
7. Select your iPhone as the run destination.
8. Press `Cmd + R` to build and install.
9. If iPhone shows untrusted developer warning:
   - `Settings` -> `General` -> `VPN & Device Management` -> trust your developer certificate.
10. Open the app and allow notifications.

## Common Issues

- **Pairing in progress**: keep iPhone unlocked and connected, wait until pairing completes.
- **CodeSign keychain password popup**: enter your Mac login password (or login keychain password).
- **No notification shown**:
  - ensure app notification permission is allowed on iPhone,
  - set a future `Reminder Time`,
  - ensure task is not marked done.

## Notes

- Local notifications are best validated on a real iPhone.
- With a free Apple ID, provisioning may expire in about 7 days; re-run from Xcode to refresh.
