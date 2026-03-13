# tasks (iOS Reminder App)

A lightweight iOS app for daily task reminders, clock-in links, and checklist tracking.

## Features

- Daily task templates with weekday repeat rules
- Today task list with quick complete toggle
- Local notifications for clock tasks
- Daily pending summary reminder
- Open clock-in site directly from task

## Requirements

- macOS + Xcode (latest stable)
- iPhone (recommended for real notification testing)
- Apple ID signed in to Xcode

## Run Locally (Simulator)

1. Clone this repository:
   - `git clone git@github.com:vectorwei/task-reminder.git`
2. Open project:
   - `clockreminder/clockreminder.xcodeproj`
3. Select an iPhone simulator in Xcode.
4. Press `Cmd + R` to build and run.
5. Allow notification permission on first launch.

## Install to Your Own iPhone

1. Connect iPhone to your Mac with cable.
2. In Xcode, open:
   - `TARGETS` -> `clockreminder` -> `Signing & Capabilities`
3. Enable:
   - `Automatically manage signing`
4. Select your Apple ID team.
5. Ensure bundle identifier is unique (example: `com.yourname.tasks`).
6. Choose your iPhone as run destination.
7. Press `Cmd + R` to install.
8. If prompted on iPhone:
   - `Settings` -> `General` -> `VPN & Device Management` -> Trust developer certificate.

## Notes

- Local notification behavior is best validated on real device.
- With free Apple ID signing, app may need re-install/re-sign after certificate expiration.
