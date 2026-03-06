# SmartSave

A native iOS app for conference networking. Scan business cards, save contact details, record conversation notes via voice, and set follow-up reminders — all on-device with no backend required.

## Features

- **Business Card Scanning** — Use your camera to scan business cards. OCR extracts name, title, company, email, and phone automatically.
- **Voice-to-Text Notes** — Record conversation notes and next steps using speech recognition. Tap the mic button and speak.
- **Follow-Up Reminders** — Set a reminder date for any contact. Get a local notification when it's time to follow up.
- **Contact Persistence** — Contacts are automatically saved to your device's Contacts app in a "SmartSave" group and card images to a "SmartSave" Photos album. Data survives app deletion.
- **Save to Device Contacts** — Export to an existing contact or create a new one in your device's address book.
- **Share Contact** — Generate and share an image card with the contact's details and business card photo.
- **Full-Screen Card Viewer** — Tap any scanned card image to view it full-screen with pinch-to-zoom and swipe-to-dismiss.
- **Editable Contacts** — All contact fields are fully editable after saving.

## Requirements

- iOS 17.0+
- Xcode 16.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

## Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/sunnixx/smartsavemynetwork.git
   cd smartsavemynetwork
   ```

2. **Install xcodegen** (if you don't have it)

   ```bash
   brew install xcodegen
   ```

3. **Generate the Xcode project**

   ```bash
   xcodegen generate
   ```

4. **Open in Xcode**

   ```bash
   open SmartSave.xcodeproj
   ```

5. **Select a simulator or device** and hit Run.

> **Note:** Camera and microphone features require a physical device. The simulator supports manual entry and editing.

## Project Structure

```
SmartSave/
├── Models/              # CoreData model and Contact entity
├── Persistence/         # PersistenceController (CoreData stack)
├── Services/
│   ├── CardScannerService    # VisionKit document camera
│   ├── CardTextParser        # Vision OCR text extraction
│   ├── VoiceInputService     # Speech framework voice-to-text
│   ├── NotificationService   # Local notification scheduling
│   ├── ContactSyncService    # Device Contacts integration
│   └── PhotoSyncService      # Photos library integration
├── ViewModels/          # AddContact and ContactDetail view models
├── Views/               # SwiftUI views
├── Assets.xcassets/     # App icon and accent color
└── Resources/           # Additional resources
```

## Tech Stack

- **SwiftUI** with iOS 17 deployment target
- **Swift 6** strict concurrency
- **CoreData** for local persistence
- **Vision** framework for OCR
- **VisionKit** for document scanning
- **Speech** framework for voice-to-text
- **Contacts** framework for device contacts sync
- **Photos** framework for image persistence
- **UserNotifications** for follow-up reminders

## License

This project is for personal/educational use.
