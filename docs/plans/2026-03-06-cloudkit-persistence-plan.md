# CloudKit Persistence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Persist all SmartSave contact data (including business card images) to iCloud via CloudKit so data survives app deletion and syncs across devices.

**Architecture:** Replace `NSPersistentContainer` with `NSPersistentCloudKitContainer`. Migrate card images from file-path references to Binary Data stored directly in CoreData (with external storage enabled), so CloudKit can sync them. Add iCloud + Background Modes capabilities.

**Tech Stack:** CoreData, CloudKit (NSPersistentCloudKitContainer), Apple Sign-In (implicit via iCloud account)

---

## Context

### Key Files
- `SmartSave/Persistence/PersistenceController.swift` — CoreData stack, currently uses `NSPersistentContainer`
- `SmartSave/Models/SmartSave.xcdatamodeld/SmartSave.xcdatamodel/contents` — CoreData model XML
- `SmartSave/Models/Contact+CoreData.swift` — Manual NSManagedObject subclass
- `SmartSave/ViewModels/AddContactViewModel.swift` — Saves card images to Documents directory as .jpg files, stores filename in `cardImagePath`
- `SmartSave/ViewModels/ContactDetailViewModel.swift` — Loads card images from Documents directory using `cardImagePath`
- `SmartSave/SmartSave.entitlements` — Currently empty
- `SmartSave/Info.plist` — App configuration
- `SmartSave/SmartSaveApp.swift` — App entry point with AppDelegate
- `project.yml` — xcodegen project definition

### Current Image Storage Pattern
Images are saved as .jpg files in the app's Documents directory. The CoreData `cardImagePath` attribute stores just the filename (e.g., `"UUID.jpg"`). On load, the filename is resolved against the Documents directory. **This won't survive app deletion** — CloudKit would sync the path string but the actual file would be gone.

### Migration Strategy
Add a new `cardImageData` attribute (Binary Data, "Allows External Storage") to the CoreData model. On first launch after update, migrate existing file-based images to this attribute, then clean up old files. Remove `cardImagePath` usage from ViewModels.

---

### Task 1: Add iCloud & Background Modes Entitlements

**Files:**
- Modify: `SmartSave/SmartSave.entitlements`
- Modify: `project.yml`

**Step 1: Update the entitlements file**

Replace the contents of `SmartSave/SmartSave.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.smartsave.app</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudDocuments</string>
        <string>CloudKit</string>
    </array>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

**Step 2: Update project.yml to declare capabilities**

Add the following under the `SmartSave` target settings:

```yaml
targets:
  SmartSave:
    type: application
    platform: iOS
    sources:
      - SmartSave
    resources:
      - SmartSave/Resources
    settings:
      base:
        INFOPLIST_FILE: SmartSave/Info.plist
        PRODUCT_NAME: SmartSave
        PRODUCT_BUNDLE_IDENTIFIER: com.smartsave.app
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    coreDataModels:
      - SmartSave/Models/SmartSave.xcdatamodeld
    entitlements:
      path: SmartSave/SmartSave.entitlements
    capabilities:
      iCloud:
        cloudKit:
          containers:
            - iCloud.com.smartsave.app
      Push Notifications: {}
      Background Modes:
        modes:
          - remote-notification
```

**Step 3: Add UIBackgroundModes to Info.plist**

Add the following key to `SmartSave/Info.plist` inside the top-level `<dict>`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

**Step 4: Regenerate Xcode project and verify**

Run:
```bash
cd "/Users/macbook/Documents/AI Products/smartsave"
xcodegen generate
```

Expected: Project regenerated with iCloud and Background Modes capabilities visible in Xcode's Signing & Capabilities tab.

**Step 5: Commit**

```bash
git add SmartSave/SmartSave.entitlements project.yml SmartSave/Info.plist
git commit -m "feat: add iCloud CloudKit and background modes entitlements"
```

---

### Task 2: Add cardImageData Attribute to CoreData Model

**Files:**
- Modify: `SmartSave/Models/SmartSave.xcdatamodeld/SmartSave.xcdatamodel/contents`
- Modify: `SmartSave/Models/Contact+CoreData.swift`

**Step 1: Add cardImageData attribute to the CoreData model XML**

Add this line after the existing `cardImagePath` attribute in the model XML:

```xml
<attribute name="cardImageData" optional="YES" attributeType="Binary" allowsExternalBinaryDataStorage="YES"/>
```

The full entity should look like:

```xml
<entity name="Contact" representedClassName="Contact" syncable="YES" codeGenerationType="none">
    <attribute name="cardImageData" optional="YES" attributeType="Binary" allowsExternalBinaryDataStorage="YES"/>
    <attribute name="cardImagePath" optional="YES" attributeType="String"/>
    <attribute name="company" optional="YES" attributeType="String"/>
    <attribute name="conversationNotes" optional="YES" attributeType="String"/>
    <attribute name="createdAt" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="email" optional="YES" attributeType="String"/>
    <attribute name="followUpDate" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="id" optional="NO" attributeType="UUID" usesScalarValueType="NO"/>
    <attribute name="name" optional="NO" attributeType="String"/>
    <attribute name="nextSteps" optional="YES" attributeType="String"/>
    <attribute name="phone" optional="YES" attributeType="String"/>
    <attribute name="title" optional="YES" attributeType="String"/>
</entity>
```

Note: Keep `cardImagePath` for now — we need it during migration. We'll remove it in a later task.

**Step 2: Add the property to Contact+CoreData.swift**

Add this line after `cardImagePath` in the Contact class:

```swift
@NSManaged public var cardImageData: Data?
```

**Step 3: Commit**

```bash
git add SmartSave/Models/
git commit -m "feat: add cardImageData binary attribute to CoreData model"
```

---

### Task 3: Switch PersistenceController to NSPersistentCloudKitContainer

**Files:**
- Modify: `SmartSave/Persistence/PersistenceController.swift`

**Step 1: Rewrite PersistenceController**

Replace the entire contents of `PersistenceController.swift` with:

```swift
import CoreData
import CloudKit

final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SmartSave")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store descriptions found")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.cloudKitContainerOptions = nil
        } else {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.smartsave.app"
            )
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores { _, error in
            if let error { fatalError("CoreData load error: \(error)") }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var context: NSManagedObjectContext { container.viewContext }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    // MARK: - CRUD

    func createContact(name: String) -> Contact {
        let contact = Contact(context: context)
        contact.id = UUID()
        contact.name = name
        contact.createdAt = Date()
        save()
        return contact
    }

    func delete(_ contact: Contact) {
        context.delete(contact)
        save()
    }

    func allContacts(searchText: String = "") -> [Contact] {
        let request = Contact.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if !searchText.isEmpty {
            request.predicate = NSPredicate(
                format: "name CONTAINS[cd] %@ OR company CONTAINS[cd] %@ OR email CONTAINS[cd] %@",
                searchText, searchText, searchText
            )
        }
        return (try? context.fetch(request)) ?? []
    }
}
```

Key changes:
- `NSPersistentContainer` → `NSPersistentCloudKitContainer`
- `import CloudKit` added
- CloudKit container options configured with `iCloud.com.smartsave.app`
- History tracking enabled (required for CloudKit sync)
- Remote change notifications enabled
- Merge policy set to `NSMergeByPropertyObjectTrumpMergePolicy` (last-writer-wins)
- In-memory mode disables CloudKit (for testing/previews)

**Step 2: Commit**

```bash
git add SmartSave/Persistence/PersistenceController.swift
git commit -m "feat: switch to NSPersistentCloudKitContainer for iCloud sync"
```

---

### Task 4: Migrate Image Storage from File Path to Binary Data

**Files:**
- Modify: `SmartSave/ViewModels/AddContactViewModel.swift`
- Modify: `SmartSave/ViewModels/ContactDetailViewModel.swift`

**Step 1: Update AddContactViewModel to store image as Binary Data**

Replace the `save()` method in `AddContactViewModel.swift` with:

```swift
func save() {
    let contact = persistence.createContact(name: name)
    contact.title = title
    contact.company = company
    contact.email = email
    contact.phone = phone
    contact.conversationNotes = conversationNotes
    contact.nextSteps = nextSteps
    if let image = cardImage, let data = image.jpegData(compressionQuality: 0.8) {
        contact.cardImageData = data
    }
    persistence.save()
}
```

Changes: Instead of writing to a file and storing the filename, we store the JPEG data directly in `cardImageData`.

**Step 2: Update ContactDetailViewModel to load image from Binary Data**

In `ContactDetailViewModel.swift`, replace the image loading in `init` (lines 34-37):

```swift
// Replace this block:
if let path = contact.cardImagePath {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
    cardImage = UIImage(contentsOfFile: url.path)
}

// With this:
if let data = contact.cardImageData {
    cardImage = UIImage(data: data)
} else if let path = contact.cardImagePath {
    // Legacy fallback: load from file and migrate to binary data
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
    if let image = UIImage(contentsOfFile: url.path) {
        cardImage = image
        contact.cardImageData = image.jpegData(compressionQuality: 0.8)
        contact.cardImagePath = nil
        try? contact.managedObjectContext?.save()
        try? FileManager.default.removeItem(at: url)
    }
}
```

This provides a lazy migration: when a contact with the old file-based storage is opened, the image is migrated to `cardImageData` inline.

**Step 3: Commit**

```bash
git add SmartSave/ViewModels/AddContactViewModel.swift SmartSave/ViewModels/ContactDetailViewModel.swift
git commit -m "feat: migrate card image storage from file path to CoreData binary data"
```

---

### Task 5: Register for Remote Notifications in AppDelegate

**Files:**
- Modify: `SmartSave/SmartSaveApp.swift`

**Step 1: Add remote notification registration**

In `SmartSaveApp.swift`, update the `didFinishLaunchingWithOptions` method to register for remote notifications:

```swift
nonisolated func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    NotificationService.requestPermission()
    application.registerForRemoteNotifications()
    return true
}
```

The single added line is `application.registerForRemoteNotifications()`. This is required for CloudKit to send push notifications when remote data changes, enabling timely sync.

**Step 2: Commit**

```bash
git add SmartSave/SmartSaveApp.swift
git commit -m "feat: register for remote notifications for CloudKit sync"
```

---

### Task 6: Regenerate Project and Verify Build

**Step 1: Regenerate the Xcode project**

```bash
cd "/Users/macbook/Documents/AI Products/smartsave"
rm -rf SmartSave.xcodeproj
xcodegen generate
```

**Step 2: Build the project**

```bash
xcodebuild -project SmartSave.xcodeproj -scheme SmartSave -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

**Step 3: Commit if any changes**

```bash
git add -A
git commit -m "chore: regenerate Xcode project with CloudKit capabilities"
```

---

## Summary of Changes

| File | Change |
|------|--------|
| `SmartSave.entitlements` | Add iCloud CloudKit + push notification entitlements |
| `project.yml` | Add iCloud, Push Notifications, Background Modes capabilities |
| `Info.plist` | Add `UIBackgroundModes` with `remote-notification` |
| `SmartSave.xcdatamodel/contents` | Add `cardImageData` Binary attribute |
| `Contact+CoreData.swift` | Add `cardImageData: Data?` property |
| `PersistenceController.swift` | Switch to `NSPersistentCloudKitContainer`, configure CloudKit options |
| `AddContactViewModel.swift` | Store image as binary data instead of file |
| `ContactDetailViewModel.swift` | Load from binary data with legacy file migration |
| `SmartSaveApp.swift` | Register for remote notifications |

## Prerequisites for Testing

1. **Apple Developer Account** — CloudKit requires a paid Apple Developer Program membership
2. **iCloud enabled** — On the test device/simulator, sign in to iCloud
3. **CloudKit Dashboard** — After first run, verify the container `iCloud.com.smartsave.app` appears at https://icloud.developer.apple.com
4. **Real device recommended** — CloudKit sync works in simulator but is more reliable on device
