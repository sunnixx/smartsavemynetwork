# Native Free Persistence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Persist all SmartSave contact data using free native iOS APIs (device Contacts + Photos library) so data survives app deletion without any paid services.

**Architecture:** On save, write to both CoreData (in-app) and device Contacts ("SmartSave" group) + Photos ("SmartSave" album). On reinstall with empty CoreData, re-import from device Contacts group and Photos album. Store notes/nextSteps/followUpDate in a structured format inside the CNContact note field.

**Tech Stack:** CoreData, Contacts framework (CNContactStore, CNGroup, CNMutableContact), Photos framework (PHPhotoLibrary, PHAssetCollection, PHAssetCreationRequest)

---

## Context

### Key Files
- `SmartSave/Persistence/PersistenceController.swift` — CoreData stack with CRUD methods
- `SmartSave/Models/Contact+CoreData.swift` — NSManagedObject subclass with properties: id, name, title, company, email, phone, cardImagePath, createdAt, conversationNotes, nextSteps, followUpDate
- `SmartSave/ViewModels/AddContactViewModel.swift` — Creates contacts, saves card images to Documents directory as .jpg, stores filename in `cardImagePath`
- `SmartSave/ViewModels/ContactDetailViewModel.swift` — Loads/edits contacts, loads images from Documents directory
- `SmartSave/Views/ContactDetailView.swift` — Already has CNContactStore code for manual "Save to Contacts" feature
- `SmartSave/Services/NotificationService.swift` — Schedules/cancels follow-up notifications
- `SmartSave/SmartSaveApp.swift` — App entry point with AppDelegate
- `SmartSave/Info.plist` — Already has NSContactsUsageDescription
- `project.yml` — xcodegen project definition

### Current "Save to Contacts" Feature
`ContactDetailView.swift` already has a manual "Save to Contacts" button that creates a `CNMutableContact` and saves it via `CNSaveRequest`. This is a one-way manual action. We need to make it automatic and bidirectional.

### Structured Note Format
We'll store SmartSave-specific data in the CNContact `note` field:
```
[SmartSave]
Notes: <text>
Next Steps: <text>
Follow-up: 2026-03-10T09:00:00Z
```

---

### Task 1: Add Photos Library Permission to Info.plist

**Files:**
- Modify: `SmartSave/Info.plist`

**Step 1: Add NSPhotoLibraryUsageDescription**

Add this key-value pair inside the top-level `<dict>` in `SmartSave/Info.plist`, after the existing `NSContactsUsageDescription` entry:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Used to save business card images so they persist if you reinstall the app</string>
```

Note: We use `NSPhotoLibraryAddUsageDescription` (add-only) rather than `NSPhotoLibraryUsageDescription` (full read/write) for the save path. However, we also need full read access for re-import on reinstall, so add both:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to retrieve your saved business card images after reinstalling the app</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Used to save business card images so they persist if you reinstall the app</string>
```

**Step 2: Regenerate Xcode project**

```bash
cd "/Users/macbook/Documents/AI Products/smartsave"
xcodegen generate
```

**Step 3: Commit**

```bash
git add SmartSave/Info.plist
git commit -m "feat: add Photos library usage descriptions to Info.plist"
```

---

### Task 2: Create ContactSyncService — Device Contacts Integration

**Files:**
- Create: `SmartSave/Services/ContactSyncService.swift`

**Step 1: Create the ContactSyncService**

Create `SmartSave/Services/ContactSyncService.swift` with the full implementation:

```swift
import Contacts
import Foundation

struct ContactSyncService {
    private static let groupName = "SmartSave"
    private static let store = CNContactStore()

    // MARK: - Permissions

    static func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    // MARK: - Group Management

    static func findOrCreateGroup() throws -> CNGroup {
        let groups = try store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: []))
        if let existing = groups.first(where: { $0.name == groupName }) {
            return existing
        }

        // Search all groups by name since predicate doesn't support name filtering
        let allGroups = try store.groups(matching: nil)
        if let existing = allGroups.first(where: { $0.name == groupName }) {
            return existing
        }

        let newGroup = CNMutableGroup()
        newGroup.name = groupName
        let saveRequest = CNSaveRequest()
        saveRequest.add(newGroup, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

        // Fetch the newly created group
        let updatedGroups = try store.groups(matching: nil)
        guard let created = updatedGroups.first(where: { $0.name == groupName }) else {
            throw SyncError.groupCreationFailed
        }
        return created
    }

    // MARK: - Save Contact to Device

    static func saveToDeviceContacts(
        name: String,
        title: String?,
        company: String?,
        email: String?,
        phone: String?,
        conversationNotes: String?,
        nextSteps: String?,
        followUpDate: Date?
    ) throws -> String {
        let group = try findOrCreateGroup()
        let cnContact = CNMutableContact()

        // Parse name into components
        let components = name.split(separator: " ", maxSplits: 1)
        cnContact.givenName = String(components.first ?? "")
        if components.count > 1 {
            cnContact.familyName = String(components[1])
        }

        if let title = title, !title.isEmpty {
            cnContact.jobTitle = title
        }
        if let company = company, !company.isEmpty {
            cnContact.organizationName = company
        }
        if let email = email, !email.isEmpty {
            cnContact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone = phone, !phone.isEmpty {
            cnContact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }

        // Store SmartSave metadata in note field
        cnContact.note = buildStructuredNote(
            conversationNotes: conversationNotes,
            nextSteps: nextSteps,
            followUpDate: followUpDate
        )

        let saveRequest = CNSaveRequest()
        saveRequest.add(cnContact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

        // Add to SmartSave group
        let addToGroupRequest = CNSaveRequest()
        addToGroupRequest.addMember(cnContact, to: group)
        try store.execute(addToGroupRequest)

        return cnContact.identifier
    }

    // MARK: - Update Existing Device Contact

    static func updateDeviceContact(
        identifier: String,
        name: String,
        title: String?,
        company: String?,
        email: String?,
        phone: String?,
        conversationNotes: String?,
        nextSteps: String?,
        followUpDate: Date?
    ) throws {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
        ]

        guard let cnContact = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch).mutableCopy() as? CNMutableContact else {
            return
        }

        let components = name.split(separator: " ", maxSplits: 1)
        cnContact.givenName = String(components.first ?? "")
        cnContact.familyName = components.count > 1 ? String(components[1]) : ""
        cnContact.jobTitle = title ?? ""
        cnContact.organizationName = company ?? ""

        if let email = email, !email.isEmpty {
            cnContact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone = phone, !phone.isEmpty {
            cnContact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }

        cnContact.note = buildStructuredNote(
            conversationNotes: conversationNotes,
            nextSteps: nextSteps,
            followUpDate: followUpDate
        )

        let saveRequest = CNSaveRequest()
        saveRequest.update(cnContact)
        try store.execute(saveRequest)
    }

    // MARK: - Import from Device Contacts

    static func importFromDeviceContacts() throws -> [ImportedContact] {
        let group: CNGroup
        do {
            let allGroups = try store.groups(matching: nil)
            guard let smartSaveGroup = allGroups.first(where: { $0.name == groupName }) else {
                return []
            }
            group = smartSaveGroup
        }

        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
        ]

        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

        return contacts.map { cn in
            let name = [cn.givenName, cn.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let parsed = parseStructuredNote(cn.note)

            return ImportedContact(
                cnIdentifier: cn.identifier,
                name: name,
                title: cn.jobTitle.isEmpty ? nil : cn.jobTitle,
                company: cn.organizationName.isEmpty ? nil : cn.organizationName,
                email: cn.emailAddresses.first?.value as String?,
                phone: cn.phoneNumbers.first?.value.stringValue,
                conversationNotes: parsed.notes,
                nextSteps: parsed.nextSteps,
                followUpDate: parsed.followUpDate
            )
        }
    }

    // MARK: - Structured Note Encoding/Decoding

    static func buildStructuredNote(
        conversationNotes: String?,
        nextSteps: String?,
        followUpDate: Date?
    ) -> String {
        var lines = ["[SmartSave]"]
        if let notes = conversationNotes, !notes.isEmpty {
            lines.append("Notes: \(notes)")
        }
        if let steps = nextSteps, !steps.isEmpty {
            lines.append("Next Steps: \(steps)")
        }
        if let date = followUpDate {
            lines.append("Follow-up: \(ISO8601DateFormatter().string(from: date))")
        }
        return lines.joined(separator: "\n")
    }

    static func parseStructuredNote(_ note: String) -> (notes: String?, nextSteps: String?, followUpDate: Date?) {
        guard note.hasPrefix("[SmartSave]") else { return (nil, nil, nil) }

        var notes: String?
        var nextSteps: String?
        var followUpDate: Date?

        for line in note.components(separatedBy: "\n") {
            if line.hasPrefix("Notes: ") {
                notes = String(line.dropFirst("Notes: ".count))
            } else if line.hasPrefix("Next Steps: ") {
                nextSteps = String(line.dropFirst("Next Steps: ".count))
            } else if line.hasPrefix("Follow-up: ") {
                let dateString = String(line.dropFirst("Follow-up: ".count))
                followUpDate = ISO8601DateFormatter().date(from: dateString)
            }
        }

        return (notes, nextSteps, followUpDate)
    }

    // MARK: - Types

    struct ImportedContact {
        let cnIdentifier: String
        let name: String
        let title: String?
        let company: String?
        let email: String?
        let phone: String?
        let conversationNotes: String?
        let nextSteps: String?
        let followUpDate: Date?
    }

    enum SyncError: Error {
        case groupCreationFailed
    }
}
```

**Step 2: Commit**

```bash
git add SmartSave/Services/ContactSyncService.swift
git commit -m "feat: add ContactSyncService for device Contacts persistence"
```

---

### Task 3: Create PhotoSyncService — Photos Library Integration

**Files:**
- Create: `SmartSave/Services/PhotoSyncService.swift`

**Step 1: Create the PhotoSyncService**

Create `SmartSave/Services/PhotoSyncService.swift`:

```swift
import Photos
import UIKit

struct PhotoSyncService {
    private static let albumName = "SmartSave"

    // MARK: - Permissions

    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    // MARK: - Album Management

    static func findOrCreateAlbum() throws -> PHAssetCollection {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let album = existing.firstObject {
            return album
        }

        var albumPlaceholder: PHObjectPlaceholder?
        try PHPhotoLibrary.shared().performChangesAndWait {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            albumPlaceholder = request.placeholderForCreatedAssetCollection
        }

        guard let placeholder = albumPlaceholder,
              let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject else {
            throw SyncError.albumCreationFailed
        }

        return album
    }

    // MARK: - Save Image

    static func saveImage(_ image: UIImage, contactName: String) throws -> String {
        let album = try findOrCreateAlbum()
        var localIdentifier = ""

        try PHPhotoLibrary.shared().performChangesAndWait {
            let creationRequest = PHAssetCreationRequest.creationRequestForAsset(from: image)
            creationRequest.creationDate = Date()

            // We don't have a direct way to tag by contact name in Photos,
            // but we can retrieve by creation date or local identifier
            guard let placeholder = creationRequest.placeholderForCreatedAsset else { return }
            localIdentifier = placeholder.localIdentifier

            // Add to album
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else { return }
            albumChangeRequest.addAssets([placeholder] as NSFastEnumeration)
        }

        return localIdentifier
    }

    // MARK: - Fetch Image by Local Identifier

    static func fetchImage(localIdentifier: String) -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true

        var result: UIImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            result = image
        }
        return result
    }

    // MARK: - Fetch All Images from Album

    static func fetchAllAlbumAssets() -> [(localIdentifier: String, image: UIImage)] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        guard let album = albums.firstObject else { return [] }

        let assetFetchOptions = PHFetchOptions()
        assetFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(in: album, options: assetFetchOptions)

        var results: [(String, UIImage)] = []
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.isSynchronous = true

        assets.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: imageOptions
            ) { image, _ in
                if let image = image {
                    results.append((asset.localIdentifier, image))
                }
            }
        }

        return results
    }

    enum SyncError: Error {
        case albumCreationFailed
    }
}
```

**Step 2: Commit**

```bash
git add SmartSave/Services/PhotoSyncService.swift
git commit -m "feat: add PhotoSyncService for Photos library image persistence"
```

---

### Task 4: Add cnContactIdentifier and photoAssetIdentifier to CoreData Model

**Files:**
- Modify: `SmartSave/Models/SmartSave.xcdatamodeld/SmartSave.xcdatamodel/contents`
- Modify: `SmartSave/Models/Contact+CoreData.swift`

**Step 1: Update the CoreData model XML**

Replace the full `<entity>` block in the model XML with:

```xml
<entity name="Contact" representedClassName="Contact" syncable="YES" codeGenerationType="none">
    <attribute name="cardImagePath" optional="YES" attributeType="String"/>
    <attribute name="cnContactIdentifier" optional="YES" attributeType="String"/>
    <attribute name="company" optional="YES" attributeType="String"/>
    <attribute name="conversationNotes" optional="YES" attributeType="String"/>
    <attribute name="createdAt" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="email" optional="YES" attributeType="String"/>
    <attribute name="followUpDate" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="id" optional="NO" attributeType="UUID" usesScalarValueType="NO"/>
    <attribute name="name" optional="NO" attributeType="String"/>
    <attribute name="nextSteps" optional="YES" attributeType="String"/>
    <attribute name="phone" optional="YES" attributeType="String"/>
    <attribute name="photoAssetIdentifier" optional="YES" attributeType="String"/>
    <attribute name="title" optional="YES" attributeType="String"/>
</entity>
```

Two new attributes:
- `cnContactIdentifier` — links to the device contact for updates
- `photoAssetIdentifier` — links to the Photos asset for image retrieval

**Step 2: Update Contact+CoreData.swift**

Replace the full file with:

```swift
import CoreData
import Foundation

@objc(Contact)
public class Contact: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var title: String?
    @NSManaged public var company: String?
    @NSManaged public var email: String?
    @NSManaged public var phone: String?
    @NSManaged public var cardImagePath: String?
    @NSManaged public var cnContactIdentifier: String?
    @NSManaged public var photoAssetIdentifier: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var conversationNotes: String?
    @NSManaged public var nextSteps: String?
    @NSManaged public var followUpDate: Date?
}

extension Contact {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Contact> {
        return NSFetchRequest<Contact>(entityName: "Contact")
    }
}
```

**Step 3: Commit**

```bash
git add SmartSave/Models/
git commit -m "feat: add cnContactIdentifier and photoAssetIdentifier to CoreData model"
```

---

### Task 5: Update AddContactViewModel — Auto-Save to Contacts & Photos

**Files:**
- Modify: `SmartSave/ViewModels/AddContactViewModel.swift`

**Step 1: Replace the save() method**

Replace the entire `save()` method in `AddContactViewModel.swift` with:

```swift
func save() {
    let contact = persistence.createContact(name: name)
    contact.title = title
    contact.company = company
    contact.email = email
    contact.phone = phone
    contact.conversationNotes = conversationNotes
    contact.nextSteps = nextSteps

    // Save card image to Documents (for in-app use)
    if let image = cardImage, let data = image.jpegData(compressionQuality: 0.8) {
        let filename = "\(UUID().uuidString).jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        try? data.write(to: url)
        contact.cardImagePath = filename

        // Save to Photos library for persistence
        if let assetId = try? PhotoSyncService.saveImage(image, contactName: name) {
            contact.photoAssetIdentifier = assetId
        }
    }

    // Auto-save to device Contacts for persistence
    if let cnId = try? ContactSyncService.saveToDeviceContacts(
        name: name,
        title: title.isEmpty ? nil : title,
        company: company.isEmpty ? nil : company,
        email: email.isEmpty ? nil : email,
        phone: phone.isEmpty ? nil : phone,
        conversationNotes: conversationNotes.isEmpty ? nil : conversationNotes,
        nextSteps: nextSteps.isEmpty ? nil : nextSteps,
        followUpDate: nil
    ) {
        contact.cnContactIdentifier = cnId
    }

    persistence.save()
}
```

**Step 2: Commit**

```bash
git add SmartSave/ViewModels/AddContactViewModel.swift
git commit -m "feat: auto-save contacts to device Contacts and Photos on creation"
```

---

### Task 6: Update ContactDetailViewModel — Sync Edits Back to Device Contacts

**Files:**
- Modify: `SmartSave/ViewModels/ContactDetailViewModel.swift`

**Step 1: Update the save() method**

Replace the `save()` method in `ContactDetailViewModel.swift` with:

```swift
func save() {
    contact.name = name
    contact.title = title
    contact.company = company
    contact.email = email
    contact.phone = phone
    contact.conversationNotes = conversationNotes
    contact.nextSteps = nextSteps
    contact.followUpDate = followUpDate

    if let date = followUpDate, let id = contact.id {
        NotificationService.schedule(contactID: id, contactName: name, date: date)
    } else if let id = contact.id {
        NotificationService.cancel(contactID: id)
    }

    // Sync edits back to device Contacts
    if let cnId = contact.cnContactIdentifier {
        try? ContactSyncService.updateDeviceContact(
            identifier: cnId,
            name: name,
            title: title.isEmpty ? nil : title,
            company: company.isEmpty ? nil : company,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            conversationNotes: conversationNotes.isEmpty ? nil : conversationNotes,
            nextSteps: nextSteps.isEmpty ? nil : nextSteps,
            followUpDate: followUpDate
        )
    }

    persistence.save()
    onSave()
}
```

**Step 2: Commit**

```bash
git add SmartSave/ViewModels/ContactDetailViewModel.swift
git commit -m "feat: sync contact edits back to device Contacts"
```

---

### Task 7: Add Re-Import on Reinstall Logic to PersistenceController

**Files:**
- Modify: `SmartSave/Persistence/PersistenceController.swift`

**Step 1: Add the importFromDeviceContactsIfNeeded method**

Add this method to `PersistenceController` after the existing `allContacts` method:

```swift
func importFromDeviceContactsIfNeeded() {
    // Only import if CoreData is empty (fresh install / reinstall)
    let request = Contact.fetchRequest()
    request.fetchLimit = 1
    let count = (try? context.count(for: request)) ?? 0
    guard count == 0 else { return }

    guard let imported = try? ContactSyncService.importFromDeviceContacts(), !imported.isEmpty else { return }

    for item in imported {
        let contact = Contact(context: context)
        contact.id = UUID()
        contact.name = item.name
        contact.title = item.title
        contact.company = item.company
        contact.email = item.email
        contact.phone = item.phone
        contact.conversationNotes = item.conversationNotes
        contact.nextSteps = item.nextSteps
        contact.followUpDate = item.followUpDate
        contact.cnContactIdentifier = item.cnIdentifier
        contact.createdAt = Date()

        // Re-schedule notification if follow-up date is in the future
        if let date = item.followUpDate, date > Date(), let id = contact.id {
            NotificationService.schedule(contactID: id, contactName: item.name, date: date)
        }
    }

    save()
}
```

**Step 2: Commit**

```bash
git add SmartSave/Persistence/PersistenceController.swift
git commit -m "feat: add re-import from device Contacts on reinstall"
```

---

### Task 8: Trigger Re-Import on App Launch

**Files:**
- Modify: `SmartSave/SmartSaveApp.swift`

**Step 1: Call importFromDeviceContactsIfNeeded on launch**

Update the `didFinishLaunchingWithOptions` method in `SmartSaveApp.swift`:

```swift
nonisolated func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    NotificationService.requestPermission()
    Task { @MainActor in
        PersistenceController.shared.importFromDeviceContactsIfNeeded()
    }
    return true
}
```

**Step 2: Commit**

```bash
git add SmartSave/SmartSaveApp.swift
git commit -m "feat: trigger contact re-import from device Contacts on app launch"
```

---

### Task 9: Request Permissions on First Launch

**Files:**
- Modify: `SmartSave/Views/ContactListView.swift`

**Step 1: Add permission requests on appear**

Read `ContactListView.swift` first to understand the current structure. Add an `.onAppear` or `.task` modifier that requests Contacts and Photos permissions on first launch. Add this inside the main view body:

```swift
.task {
    _ = await ContactSyncService.requestAccess()
    _ = await PhotoSyncService.requestAccess()
}
```

This should be added to the outermost view in `ContactListView`'s body. The exact placement depends on the current structure — add it to the `NavigationStack` or top-level container.

**Step 2: Commit**

```bash
git add SmartSave/Views/ContactListView.swift
git commit -m "feat: request Contacts and Photos permissions on first launch"
```

---

### Task 10: Regenerate Project and Verify Build

**Step 1: Regenerate the Xcode project**

```bash
cd "/Users/macbook/Documents/AI Products/smartsave"
rm -rf SmartSave.xcodeproj
xcodegen generate
```

**Step 2: Build the project**

```bash
xcodebuild -project SmartSave.xcodeproj -scheme SmartSave -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

If there are Swift 6 concurrency warnings, address them by:
- Adding `@preconcurrency import Photos` or `@preconcurrency import Contacts` if needed
- Ensuring sync service methods called from MainActor contexts are handled properly

**Step 3: Commit if any fixes**

```bash
git add -A
git commit -m "chore: regenerate Xcode project and fix build issues"
```

---

## Summary of Changes

| File | Change |
|------|--------|
| `Info.plist` | Add Photos library usage descriptions |
| `ContactSyncService.swift` | NEW — Save/update/import contacts via device Contacts "SmartSave" group |
| `PhotoSyncService.swift` | NEW — Save/fetch images via Photos "SmartSave" album |
| `SmartSave.xcdatamodel/contents` | Add `cnContactIdentifier` and `photoAssetIdentifier` attributes |
| `Contact+CoreData.swift` | Add `cnContactIdentifier` and `photoAssetIdentifier` properties |
| `AddContactViewModel.swift` | Auto-save to device Contacts and Photos on contact creation |
| `ContactDetailViewModel.swift` | Sync edits back to device Contacts |
| `PersistenceController.swift` | Add `importFromDeviceContactsIfNeeded()` for reinstall recovery |
| `SmartSaveApp.swift` | Trigger re-import on app launch |
| `ContactListView.swift` | Request Contacts and Photos permissions |

## Testing Checklist

1. Create a contact with card image → verify it appears in device Contacts under "SmartSave" group
2. Check Photos app → verify card image in "SmartSave" album
3. Edit contact in SmartSave → verify changes reflected in device Contacts
4. Delete SmartSave app → reinstall → verify contacts re-imported from device Contacts
5. Verify follow-up reminders re-scheduled after reinstall
6. Deny Contacts permission → verify app still works (just without persistence)
7. Deny Photos permission → verify contacts save without images
