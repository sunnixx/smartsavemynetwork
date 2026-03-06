# CloudKit Persistence for SmartSave

## Goal

Persist all SmartSave contact data (names, emails, phones, notes, next steps, reminders, business card images) in iCloud via CloudKit so data survives app deletion and syncs across devices.

## Architecture

Replace `NSPersistentContainer` with `NSPersistentCloudKitContainer` in `PersistenceController`. CloudKit automatically mirrors the local CoreData store to the user's iCloud account.

**Authentication:** Apple Sign-In. The user's Apple ID ties to their iCloud account, which CloudKit uses automatically.

**Tech Stack:** CoreData + CloudKit (NSPersistentCloudKitContainer), Apple Sign-In.

## What Changes

1. **PersistenceController** — Switch from `NSPersistentContainer` to `NSPersistentCloudKitContainer`
2. **Store description** — Configure with CloudKit container identifier (`iCloud.com.smartsave.app`), enable history tracking and remote change notifications
3. **Entitlements** — Add iCloud (CloudKit) capability and Background Modes (remote notifications)
4. **project.yml** — Add iCloud and background modes capabilities

## What Stays the Same

- CoreData model, entities, and attributes (zero schema changes)
- All fetch requests, saves, and view code
- App works offline; CloudKit syncs when connectivity is available

## User Experience

- First launch: user signs in with Apple ID (or already signed in)
- Data syncs silently in background
- Delete and reinstall: data reappears automatically
- Multi-device: contacts appear on all devices with same Apple ID

## Error Handling

- **iCloud not signed in:** App works fully offline. Subtle banner: "Sign in to iCloud to back up your contacts."
- **iCloud storage full:** Local data unaffected. Alert only on persistent sync errors.
- **No network:** Writes go to local store. CloudKit syncs on reconnect.
- **Reinstall:** Data pulls down automatically after sign-in.
- **Merge conflicts:** Last-writer-wins (NSPersistentCloudKitContainer default). Acceptable for single-user app.

## Out of Scope

- Custom sync UI or manual backup/restore
- Cross-platform support
- Sharing contacts between users
- Migration wizard (existing data auto-syncs on first CloudKit sync)
