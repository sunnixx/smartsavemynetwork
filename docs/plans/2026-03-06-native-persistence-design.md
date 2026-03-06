# Native Free Persistence for SmartSave

## Goal

Persist all SmartSave contact data using free native iOS APIs so data survives app deletion — device Contacts for text data, Photos library for card images.

## Architecture

On save, SmartSave writes contact data to both CoreData (in-app) and device Contacts (persistence). Card images go to a "SmartSave" Photos album. On reinstall with empty CoreData, the app re-imports from the "SmartSave" contact group and Photos album.

**Tech Stack:** CoreData (in-app), Contacts framework (CNContactStore, CNGroup), Photos framework (PHPhotoLibrary, PHAssetCollection)

## Data Storage Strategy

| Data | Storage | Survives deletion? |
|------|---------|-------------------|
| Name, title, company, email, phone | Device Contacts in "SmartSave" group | Yes |
| Conversation notes, next steps, follow-up date | CNContact note field (structured format) | Yes |
| Business card images | Photos library in "SmartSave" album | Yes |
| All of the above | CoreData (primary in-app store) | No |

## Structured Note Format

```
[SmartSave]
Notes: <conversation notes text>
Next Steps: <next steps text>
Follow-up: <ISO 8601 date string>
```

## On Save Flow

1. Save to CoreData (as today)
2. Create/find "SmartSave" group in device Contacts
3. Save CNContact with all fields + structured note, add to group
4. Save card image to "SmartSave" Photos album
5. Store Photos asset local identifier in CoreData for linking

## On Reinstall Flow

1. First launch detects empty CoreData
2. Fetch all contacts from "SmartSave" group in device Contacts
3. Import each into CoreData, parsing structured note for notes/nextSteps/followUpDate
4. Re-schedule notifications for future follow-up dates
5. Fetch images from "SmartSave" Photos album, re-link by matching contact name

## Error Handling

- Contacts permission denied: App works but data won't persist through deletion. Show settings prompt.
- Photos permission denied: Card images won't persist. Show note to user.
- No "SmartSave" group found on reinstall: Fresh start, no data to import.

## Out of Scope

- No backend, no accounts, no paid services
- No iCloud or CloudKit
- No cross-device sync
