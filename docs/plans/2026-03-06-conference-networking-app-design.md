# Conference Networking App — Design Document

**Date:** 2026-03-06
**Platform:** iOS (native)
**Stack:** SwiftUI, VisionKit, Apple Speech, CoreData, UserNotifications

---

## Problem

At conferences, saving a contact's information, conversation notes, and next steps is slow and disjointed. Business cards get lost, mental notes fade, and follow-ups fall through the cracks.

## Goal

A simple iOS app that makes it fast to capture a contact right after meeting them — scan their card, add notes by voice or text, set a reminder, and move on.

---

## Architecture

- **UI:** SwiftUI
- **Card scanning + OCR:** VisionKit (`VNDocumentCameraViewController`) + Vision framework (`VNRecognizeTextRequest`)
- **Voice-to-text:** Apple Speech framework (`SFSpeechRecognizer`) — fully on-device, no API needed
- **Persistence:** CoreData (local, no backend)
- **Reminders:** UserNotifications (local push notifications)
- **Search:** CoreData `NSPredicate` filtering in real-time

No accounts. No backend. Everything lives on-device.

---

## Data Model

```
Contact
├── id (UUID)
├── name (String)
├── title (String)
├── company (String)
├── email (String)
├── phone (String)
├── cardImagePath (String?)     — file path to saved card photo
├── createdAt (Date)            — when contact was added
├── conversationNotes (String)  — free-form notes from the conversation
├── nextSteps (String)          — user-written follow-up actions
└── followUpDate (Date?)        — optional reminder date/time
```

---

## Screens

### 1. Home — Contact List
- Scrollable list of contacts sorted by most recent
- Each row: name, company, follow-up date badge (if set)
- Search bar filters by name, company, email in real-time
- FAB (floating action button) to add a new contact

### 2. Add Contact
Two entry points accessible from the FAB:
- **Scan Card** — opens VisionKit camera, scans card, auto-fills fields
- **Add Manually** — opens blank form

Both lead to the same edit form. User can correct any auto-filled field before saving.

### 3. Contact Detail
- Full contact info (name, title, company, email, phone)
- Card photo thumbnail (if scanned)
- Conversation notes section
- Next steps section
- Follow-up reminder date (with option to set/edit)
- Edit button to modify any field

### 4. Notes & Next Steps Screen
- Two text areas: "Conversation Notes" and "Next Steps"
- Microphone button on each field for voice-to-text input
- Tap mic to start recording, tap again to stop — transcript appends to field
- Save button commits changes

### 5. Reminder Picker
- Native date/time picker
- Sets a local push notification for that date/time
- Notification title includes the contact's name
- Tapping the notification deep-links to the contact's detail screen

---

## Key User Flow

```
Meet someone
  → Tap FAB → "Scan Card" or "Add Manually"
  → Review/correct extracted fields
  → Add conversation notes (type or voice)
  → Write next steps
  → Set follow-up reminder (optional)
  → Save → back to contact list
```

---

## Technical Details

### Card Scanning & OCR
- `VNDocumentCameraViewController` captures a clean, perspective-corrected card image
- `VNRecognizeTextRequest` extracts all text from the image
- Heuristic parser maps text to fields:
  - Email: regex match for `@`
  - Phone: regex match for digit patterns
  - Name: typically the largest/first text block
  - Title & company: remaining lines
- Raw card image saved to app's documents directory

### Voice-to-Text
- `SFSpeechRecognizer` with `AVAudioEngine` for live transcription
- Works fully on-device (no network required)
- Microphone button: tap to start, tap again to stop
- Transcribed text appends (does not replace) existing notes

### Reminders
- `UNUserNotificationCenter` for scheduling local notifications
- Permission requested on first use
- Notification payload includes contact ID for deep-linking
- `onReceive` in SwiftUI handles notification tap → navigate to contact

### Search
- `NSFetchedResultsController` with `NSPredicate` for real-time filtering
- Searches across: name, company, email

---

## Out of Scope (for now)
- Cloud sync or backup
- Export to contacts / CRM / CSV
- Android support
- AI-generated next steps
- Contact sharing between users
