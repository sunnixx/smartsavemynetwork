# SmartSave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native iOS app for capturing conference contacts via card scanning or manual entry, with voice/text notes, next steps, and follow-up reminders.

**Architecture:** SwiftUI views backed by ViewModels, a PersistenceController wrapping CoreData, and focused Services for scanning, voice input, and notifications. All data stays on-device — no backend, no accounts.

**Tech Stack:** SwiftUI, VisionKit, Vision framework, SFSpeechRecognizer, CoreData, UserNotifications, XCTest

---

## Project Structure

```
SmartSave/
├── SmartSaveApp.swift
├── Models/
│   └── SmartSave.xcdatamodeld        (CoreData schema)
├── Persistence/
│   └── PersistenceController.swift
├── Services/
│   ├── CardScannerService.swift
│   ├── CardTextParser.swift
│   ├── VoiceInputService.swift
│   └── NotificationService.swift
├── ViewModels/
│   ├── ContactListViewModel.swift
│   ├── AddContactViewModel.swift
│   └── ContactDetailViewModel.swift
└── Views/
    ├── ContactListView.swift
    ├── AddContactView.swift
    ├── ContactDetailView.swift
    ├── NotesView.swift
    └── ReminderPickerView.swift

SmartSaveTests/
├── CardTextParserTests.swift
├── PersistenceControllerTests.swift
└── NotificationServiceTests.swift
```

---

### Task 1: Create Xcode Project

**Files:**
- Create: `SmartSave.xcodeproj` (via Xcode)

**Step 1: Create project in Xcode**

Open Xcode → New Project → App
- Product Name: `SmartSave`
- Interface: `SwiftUI`
- Language: `Swift`
- Check: `Use Core Data`
- Check: `Include Tests`
- Save to: `~/Documents/AI Products/smartsave/`

**Step 2: Clean up Xcode boilerplate**

Delete these Xcode-generated files (move to trash):
- `ContentView.swift` (we'll make our own views)
- `Item.swift` (generated CoreData class — we'll define our own model)

**Step 3: Add required permissions to Info.plist**

Add these keys to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan business cards</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Used to transcribe your spoken notes</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used to record voice notes</string>
```

**Step 4: Build to verify clean state**

Press `Cmd+B`. Expected: Build Succeeded with 0 errors.

**Step 5: Commit**

```bash
cd "/Users/macbook/Documents/AI Products/smartsave"
git init
git add .
git commit -m "feat: initial Xcode project with CoreData and test targets"
```

---

### Task 2: CoreData Model

**Files:**
- Modify: `SmartSave.xcdatamodeld`
- Create: `Persistence/PersistenceController.swift`
- Create: `SmartSaveTests/PersistenceControllerTests.swift`

**Step 1: Define the Contact entity in Xcode's model editor**

Open `SmartSave.xcdatamodeld`. Add entity `Contact` with these attributes:

| Attribute           | Type    | Optional |
|---------------------|---------|----------|
| id                  | UUID    | No       |
| name                | String  | No       |
| title               | String  | Yes      |
| company             | String  | Yes      |
| email               | String  | Yes      |
| phone               | String  | Yes      |
| cardImagePath       | String  | Yes      |
| createdAt           | Date    | No       |
| conversationNotes   | String  | Yes      |
| nextSteps           | String  | Yes      |
| followUpDate        | Date    | Yes      |

In the entity inspector, set **Codegen** to `Manual/None` (we'll write the class ourselves).

**Step 2: Create the Contact NSManagedObject subclass**

Create `Models/Contact+CoreData.swift`:

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

**Step 3: Create PersistenceController**

Create `Persistence/PersistenceController.swift`:

```swift
import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SmartSave")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("CoreData load error: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
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

**Step 4: Write failing tests**

Create `SmartSaveTests/PersistenceControllerTests.swift`:

```swift
import XCTest
import CoreData
@testable import SmartSave

final class PersistenceControllerTests: XCTestCase {
    var sut: PersistenceController!

    override func setUp() {
        super.setUp()
        sut = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_createContact_setsIdAndCreatedAt() {
        let contact = sut.createContact(name: "Jane Doe")
        XCTAssertNotNil(contact.id)
        XCTAssertNotNil(contact.createdAt)
        XCTAssertEqual(contact.name, "Jane Doe")
    }

    func test_allContacts_returnsAllWhenNoSearch() {
        sut.createContact(name: "Alice")
        sut.createContact(name: "Bob")
        XCTAssertEqual(sut.allContacts().count, 2)
    }

    func test_allContacts_filtersbySearchText() {
        sut.createContact(name: "Alice Smith")
        sut.createContact(name: "Bob Jones")
        let results = sut.allContacts(searchText: "alice")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Alice Smith")
    }

    func test_delete_removesContact() {
        let contact = sut.createContact(name: "Delete Me")
        sut.delete(contact)
        XCTAssertEqual(sut.allContacts().count, 0)
    }
}
```

**Step 5: Run tests to verify they fail**

`Cmd+U` in Xcode or: `xcodebuild test -scheme SmartSave -destination 'platform=iOS Simulator,name=iPhone 16'`

Expected: Compile error or test failure — `PersistenceController` not yet added to target.

**Step 6: Add files to the SmartSave target in Xcode**

In Xcode's file inspector for each new file, ensure **Target Membership** includes `SmartSave`.

**Step 7: Run tests again**

Expected: All 4 tests PASS.

**Step 8: Commit**

```bash
git add .
git commit -m "feat: CoreData model and PersistenceController with CRUD and search"
```

---

### Task 3: Card Text Parser

**Files:**
- Create: `Services/CardTextParser.swift`
- Create: `SmartSaveTests/CardTextParserTests.swift`

**Step 1: Write failing tests**

Create `SmartSaveTests/CardTextParserTests.swift`:

```swift
import XCTest
@testable import SmartSave

final class CardTextParserTests: XCTestCase {

    func test_parsesEmail() {
        let lines = ["John Smith", "Engineer", "Acme Corp", "john@acme.com", "+1 555-123-4567"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.email, "john@acme.com")
    }

    func test_parsesPhone() {
        let lines = ["Jane Doe", "CEO", "Beta Inc", "jane@beta.io", "(415) 222-3333"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.phone, "(415) 222-3333")
    }

    func test_parsesName_asFirstLine() {
        let lines = ["Sarah Connor", "Director", "Cyberdyne", "sarah@cyberdyne.com"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.name, "Sarah Connor")
    }

    func test_parsesCompanyAndTitle_fromRemainingLines() {
        let lines = ["Tom Hardy", "VP Sales", "MegaCorp", "tom@mega.com", "800-555-0001"]
        let result = CardTextParser.parse(lines)
        // title is second non-name, non-email, non-phone line
        XCTAssertEqual(result.title, "VP Sales")
        XCTAssertEqual(result.company, "MegaCorp")
    }

    func test_handlesEmptyInput() {
        let result = CardTextParser.parse([])
        XCTAssertNil(result.email)
        XCTAssertNil(result.phone)
        XCTAssertNil(result.name)
    }
}
```

**Step 2: Run to verify tests fail**

`Cmd+U`. Expected: Compile error — `CardTextParser` not defined.

**Step 3: Implement CardTextParser**

Create `Services/CardTextParser.swift`:

```swift
import Foundation

struct ParsedCard {
    var name: String?
    var title: String?
    var company: String?
    var email: String?
    var phone: String?
}

struct CardTextParser {
    static func parse(_ lines: [String]) -> ParsedCard {
        var result = ParsedCard()
        var remaining: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isEmail(trimmed) {
                result.email = trimmed
            } else if isPhone(trimmed) {
                result.phone = trimmed
            } else {
                remaining.append(trimmed)
            }
        }

        if !remaining.isEmpty { result.name = remaining[0] }
        if remaining.count > 1  { result.title = remaining[1] }
        if remaining.count > 2  { result.company = remaining[2] }

        return result
    }

    private static func isEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isPhone(_ s: String) -> Bool {
        let pattern = #"[\d\s\(\)\-\+\.]{7,}"#
        let digits = s.filter { $0.isNumber }
        return digits.count >= 7 && s.range(of: pattern, options: .regularExpression) != nil
    }
}
```

**Step 4: Run tests**

`Cmd+U`. Expected: All 5 `CardTextParserTests` PASS.

**Step 5: Commit**

```bash
git add .
git commit -m "feat: CardTextParser extracts name, title, company, email, phone from OCR lines"
```

---

### Task 4: Notification Service

**Files:**
- Create: `Services/NotificationService.swift`
- Create: `SmartSaveTests/NotificationServiceTests.swift`

**Step 1: Write failing tests**

Create `SmartSaveTests/NotificationServiceTests.swift`:

```swift
import XCTest
import UserNotifications
@testable import SmartSave

final class NotificationServiceTests: XCTestCase {

    func test_buildRequest_hasCorrectIdentifier() {
        let contactID = UUID()
        let date = Date().addingTimeInterval(3600)
        let request = NotificationService.buildRequest(contactID: contactID, contactName: "Alice", date: date)
        XCTAssertEqual(request.identifier, contactID.uuidString)
    }

    func test_buildRequest_titleContainsContactName() {
        let contactID = UUID()
        let date = Date().addingTimeInterval(3600)
        let request = NotificationService.buildRequest(contactID: contactID, contactName: "Bob", date: date)
        let content = request.content
        XCTAssertTrue(content.title.contains("Bob"))
    }
}
```

**Step 2: Run to verify tests fail**

Expected: Compile error — `NotificationService` not defined.

**Step 3: Implement NotificationService**

Create `Services/NotificationService.swift`:

```swift
import UserNotifications
import Foundation

struct NotificationService {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(contactID: UUID, contactName: String, date: Date) {
        let request = buildRequest(contactID: contactID, contactName: contactName, date: date)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(contactID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [contactID.uuidString])
    }

    // Internal: separated for testability
    static func buildRequest(contactID: UUID, contactName: String, date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Follow up with \(contactName)"
        content.body = "You set a reminder to follow up."
        content.sound = .default
        content.userInfo = ["contactID": contactID.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(identifier: contactID.uuidString, content: content, trigger: trigger)
    }
}
```

**Step 4: Run tests**

`Cmd+U`. Expected: Both `NotificationServiceTests` PASS.

**Step 5: Commit**

```bash
git add .
git commit -m "feat: NotificationService schedules and cancels local follow-up reminders"
```

---

### Task 5: App Entry Point & Navigation

**Files:**
- Modify: `SmartSaveApp.swift`
- Create: `Views/ContactListView.swift`
- Create: `ViewModels/ContactListViewModel.swift`

**Step 1: Create ContactListViewModel**

Create `ViewModels/ContactListViewModel.swift`:

```swift
import Foundation
import Combine

class ContactListViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var searchText: String = "" {
        didSet { fetch() }
    }

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        fetch()
    }

    func fetch() {
        contacts = persistence.allContacts(searchText: searchText)
    }

    func delete(at offsets: IndexSet) {
        offsets.map { contacts[$0] }.forEach {
            NotificationService.cancel(contactID: $0.id ?? UUID())
            persistence.delete($0)
        }
        fetch()
    }
}
```

**Step 2: Create ContactListView**

Create `Views/ContactListView.swift`:

```swift
import SwiftUI

struct ContactListView: View {
    @StateObject private var vm = ContactListViewModel()
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.contacts, id: \.id) { contact in
                    NavigationLink(destination: ContactDetailView(contact: contact, onSave: vm.fetch)) {
                        ContactRowView(contact: contact)
                    }
                }
                .onDelete(perform: vm.delete)
            }
            .searchable(text: $vm.searchText, prompt: "Search by name, company, email")
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: vm.fetch) {
                AddContactView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.fetch()
        }
    }
}

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name ?? "Unknown")
                .font(.headline)
            if let company = contact.company, !company.isEmpty {
                Text(company)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .trailing) {
            if let followUp = contact.followUpDate {
                Text(followUp, style: .date)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 4)
            }
        }
    }
}
```

**Step 3: Update SmartSaveApp.swift**

Replace the contents of `SmartSaveApp.swift`:

```swift
import SwiftUI
import UserNotifications

@main
struct SmartSaveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContactListView()
                .environment(\.managedObjectContext, PersistenceController.shared.context)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.requestPermission()
        return true
    }

    // Handle notification tap → deep link to contact
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let idString = response.notification.request.content.userInfo["contactID"] as? String,
              let contactID = UUID(uuidString: idString) else { return }
        NotificationCenter.default.post(name: .openContact, object: contactID)
    }
}

extension Notification.Name {
    static let openContact = Notification.Name("openContact")
}
```

**Step 4: Build and run on simulator**

`Cmd+R`. Expected: App launches showing an empty contact list with a + button and search bar.

**Step 5: Commit**

```bash
git add .
git commit -m "feat: contact list view with search, delete, and navigation shell"
```

---

### Task 6: Add Contact Flow (Manual Entry)

**Files:**
- Create: `Views/AddContactView.swift`
- Create: `ViewModels/AddContactViewModel.swift`

**Step 1: Create AddContactViewModel**

Create `ViewModels/AddContactViewModel.swift`:

```swift
import Foundation
import SwiftUI

class AddContactViewModel: ObservableObject {
    @Published var name = ""
    @Published var title = ""
    @Published var company = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var cardImage: UIImage?

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func populate(from parsed: ParsedCard, image: UIImage?) {
        name = parsed.name ?? ""
        title = parsed.title ?? ""
        company = parsed.company ?? ""
        email = parsed.email ?? ""
        phone = parsed.phone ?? ""
        cardImage = image
    }

    func save() {
        let contact = persistence.createContact(name: name)
        contact.title = title
        contact.company = company
        contact.email = email
        contact.phone = phone
        if let image = cardImage, let data = image.jpegData(compressionQuality: 0.8) {
            let filename = "\(UUID().uuidString).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            try? data.write(to: url)
            contact.cardImagePath = filename
        }
        persistence.save()
    }
}
```

**Step 2: Create AddContactView**

Create `Views/AddContactView.swift`:

```swift
import SwiftUI
import VisionKit

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddContactViewModel()
    @State private var showScanner = false
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan Business Card", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    showForm = true
                } label: {
                    Label("Enter Manually", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                CardScannerView { parsed, image in
                    vm.populate(from: parsed, image: image)
                    showScanner = false
                    showForm = true
                }
            }
            .sheet(isPresented: $showForm, onDismiss: dismiss) {
                ContactFormView(vm: vm, onSave: {
                    vm.save()
                    dismiss()
                })
            }
        }
    }
}

struct ContactFormView: View {
    @ObservedObject var vm: AddContactViewModel
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let image = vm.cardImage {
                    Section("Card") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .cornerRadius(8)
                    }
                }
                Section("Contact Info") {
                    TextField("Name *", text: $vm.name)
                    TextField("Title", text: $vm.title)
                    TextField("Company", text: $vm.company)
                    TextField("Email", text: $vm.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $vm.phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Contact Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
```

**Step 3: Build and run**

`Cmd+R`. Tap +, verify both buttons appear. Tap "Enter Manually" → form appears → fill in a name → Save. Verify contact appears in list.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add contact flow with manual entry form"
```

---

### Task 7: Card Scanner (VisionKit + OCR)

**Files:**
- Create: `Services/CardScannerService.swift`
- Modify: `Views/AddContactView.swift` (add `CardScannerView`)

**Step 1: Create CardScannerService**

Create `Services/CardScannerService.swift`:

```swift
import Vision
import UIKit

struct CardScannerService {
    static func extractText(from image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        let request = VNRecognizeTextRequest { request, _ in
            let lines = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
            DispatchQueue.main.async { completion(lines) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
```

**Step 2: Add CardScannerView to AddContactView.swift**

Add this view at the bottom of `AddContactView.swift` (before the last closing brace of the file):

```swift
struct CardScannerView: UIViewControllerRepresentable {
    let onResult: (ParsedCard, UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onResult: (ParsedCard, UIImage?) -> Void
        init(onResult: @escaping (ParsedCard, UIImage?) -> Void) { self.onResult = onResult }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                onResult(ParsedCard(), nil)
                return
            }
            let image = scan.imageOfPage(at: 0)
            CardScannerService.extractText(from: image) { lines in
                let parsed = CardTextParser.parse(lines)
                self.onResult(parsed, image)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onResult(ParsedCard(), nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onResult(ParsedCard(), nil)
        }
    }
}
```

**Step 3: Build and run on a physical device**

Note: VisionKit camera requires a real device (not simulator).

`Cmd+R` on device. Tap + → Scan Card → point camera at a business card → capture → verify fields auto-fill.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: VisionKit card scanning with OCR auto-fill"
```

---

### Task 8: Contact Detail View

**Files:**
- Create: `Views/ContactDetailView.swift`
- Create: `ViewModels/ContactDetailViewModel.swift`

**Step 1: Create ContactDetailViewModel**

Create `ViewModels/ContactDetailViewModel.swift`:

```swift
import Foundation
import UIKit

class ContactDetailViewModel: ObservableObject {
    @Published var name: String
    @Published var title: String
    @Published var company: String
    @Published var email: String
    @Published var phone: String
    @Published var conversationNotes: String
    @Published var nextSteps: String
    @Published var followUpDate: Date?
    @Published var cardImage: UIImage?

    private let contact: Contact
    private let persistence: PersistenceController
    let onSave: () -> Void

    init(contact: Contact, persistence: PersistenceController = .shared, onSave: @escaping () -> Void) {
        self.contact = contact
        self.persistence = persistence
        self.onSave = onSave

        name = contact.name ?? ""
        title = contact.title ?? ""
        company = contact.company ?? ""
        email = contact.email ?? ""
        phone = contact.phone ?? ""
        conversationNotes = contact.conversationNotes ?? ""
        nextSteps = contact.nextSteps ?? ""
        followUpDate = contact.followUpDate

        if let path = contact.cardImagePath {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
            cardImage = UIImage(contentsOfFile: url.path)
        }
    }

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

        persistence.save()
        onSave()
    }
}
```

**Step 2: Create ContactDetailView**

Create `Views/ContactDetailView.swift`:

```swift
import SwiftUI

struct ContactDetailView: View {
    @StateObject private var vm: ContactDetailViewModel
    @State private var isEditing = false
    @State private var showNotes = false
    @State private var showReminderPicker = false

    init(contact: Contact, onSave: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ContactDetailViewModel(contact: contact, onSave: onSave))
    }

    var body: some View {
        List {
            if let image = vm.cardImage {
                Section("Business Card") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .cornerRadius(8)
                }
            }

            Section("Contact Info") {
                DetailRow(label: "Name", value: vm.name)
                DetailRow(label: "Title", value: vm.title)
                DetailRow(label: "Company", value: vm.company)
                DetailRow(label: "Email", value: vm.email)
                DetailRow(label: "Phone", value: vm.phone)
            }

            Section("Conversation Notes") {
                if vm.conversationNotes.isEmpty {
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                } else {
                    Text(vm.conversationNotes)
                }
                Button("Edit Notes") { showNotes = true }
                    .foregroundColor(.accentColor)
            }

            Section("Next Steps") {
                if vm.nextSteps.isEmpty {
                    Text("No next steps")
                        .foregroundColor(.secondary)
                } else {
                    Text(vm.nextSteps)
                }
                Button("Edit Next Steps") { showNotes = true }
                    .foregroundColor(.accentColor)
            }

            Section("Follow-up Reminder") {
                if let date = vm.followUpDate {
                    HStack {
                        Text(date, style: .date)
                        Spacer()
                        Text(date, style: .time)
                            .foregroundColor(.secondary)
                    }
                    Button("Remove Reminder") {
                        vm.followUpDate = nil
                        vm.save()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Set Reminder") { showReminderPicker = true }
                        .foregroundColor(.accentColor)
                }
            }
        }
        .navigationTitle(vm.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showNotes, onDismiss: vm.save) {
            NotesView(notes: $vm.conversationNotes, nextSteps: $vm.nextSteps)
        }
        .sheet(isPresented: $showReminderPicker) {
            ReminderPickerView(selectedDate: $vm.followUpDate, onConfirm: {
                showReminderPicker = false
                vm.save()
            })
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
        }
    }
}
```

**Step 3: Build and run**

`Cmd+R`. Add a contact manually → tap it → verify detail view shows all fields, notes section, and reminder section.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: contact detail view with notes and reminder sections"
```

---

### Task 9: Notes View with Voice-to-Text

**Files:**
- Create: `Services/VoiceInputService.swift`
- Create: `Views/NotesView.swift`

**Step 1: Create VoiceInputService**

Create `Services/VoiceInputService.swift`:

```swift
import Speech
import AVFoundation
import Foundation

class VoiceInputService: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer()
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    func startRecording(appending existingText: String) {
        guard !isRecording else { return }

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        try? engine.start()
        isRecording = true

        task = recognizer?.recognitionTask(with: request!) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let newText = result.bestTranscription.formattedString
                self.transcript = existingText.isEmpty ? newText : existingText + " " + newText
            }
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
    }

    func stopRecording() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isRecording = false
    }
}
```

**Step 2: Create NotesView**

Create `Views/NotesView.swift`:

```swift
import SwiftUI

struct NotesView: View {
    @Binding var notes: String
    @Binding var nextSteps: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceNotes = VoiceInputService()
    @StateObject private var voiceNextSteps = VoiceInputService()
    @State private var activeField: Field?

    enum Field { case notes, nextSteps }

    var body: some View {
        NavigationStack {
            Form {
                Section("Conversation Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .onChange(of: voiceNotes.transcript) { notes = $0 }

                    MicButton(service: voiceNotes, existingText: notes)
                }

                Section("Next Steps") {
                    TextEditor(text: $nextSteps)
                        .frame(minHeight: 100)
                        .onChange(of: voiceNextSteps.transcript) { nextSteps = $0 }

                    MicButton(service: voiceNextSteps, existingText: nextSteps)
                }
            }
            .navigationTitle("Notes & Next Steps")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        voiceNotes.stopRecording()
                        voiceNextSteps.stopRecording()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MicButton: View {
    @ObservedObject var service: VoiceInputService
    let existingText: String

    var body: some View {
        Button {
            if service.isRecording {
                service.stopRecording()
            } else {
                service.startRecording(appending: existingText)
            }
        } label: {
            Label(
                service.isRecording ? "Stop Recording" : "Speak Notes",
                systemImage: service.isRecording ? "stop.circle.fill" : "mic.circle"
            )
            .foregroundColor(service.isRecording ? .red : .accentColor)
        }
    }
}
```

**Step 3: Build and run on a physical device**

Speech recognition requires a real device.

`Cmd+R` on device. Open a contact → tap "Edit Notes" → tap microphone → speak → verify text appears.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: voice-to-text notes using SFSpeechRecognizer"
```

---

### Task 10: Reminder Picker

**Files:**
- Create: `Views/ReminderPickerView.swift`

**Step 1: Create ReminderPickerView**

Create `Views/ReminderPickerView.swift`:

```swift
import SwiftUI

struct ReminderPickerView: View {
    @Binding var selectedDate: Date?
    let onConfirm: () -> Void
    @State private var pickedDate = Date().addingTimeInterval(86400) // default: tomorrow

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker(
                    "Follow-up Date",
                    selection: $pickedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onConfirm() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        selectedDate = pickedDate
                        onConfirm()
                    }
                }
            }
        }
    }
}
```

**Step 2: Build and run**

`Cmd+R`. Open a contact → tap "Set Reminder" → pick a date → tap Set → verify the date appears in the detail view and a local notification is scheduled.

Verify notification: Settings app → Notifications → SmartSave should show a pending notification.

**Step 3: Commit**

```bash
git add .
git commit -m "feat: reminder picker with local notification scheduling"
```

---

### Task 11: Notification Deep-Link Handling

**Files:**
- Modify: `Views/ContactListView.swift`

**Step 1: Add deep-link handler to ContactListView**

In `ContactListView.swift`, add a `@State` for the navigation path and handle the `openContact` notification.

Replace the `body` in `ContactListView` with:

```swift
@State private var navigationPath = NavigationPath()

var body: some View {
    NavigationStack(path: $navigationPath) {
        List {
            ForEach(vm.contacts, id: \.id) { contact in
                NavigationLink(value: contact) {
                    ContactRowView(contact: contact)
                }
            }
            .onDelete(perform: vm.delete)
        }
        .searchable(text: $vm.searchText, prompt: "Search by name, company, email")
        .navigationTitle("Contacts")
        .navigationDestination(for: Contact.self) { contact in
            ContactDetailView(contact: contact, onSave: vm.fetch)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: vm.fetch) {
            AddContactView()
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: .openContact)) { note in
        guard let contactID = note.object as? UUID,
              let contact = vm.contacts.first(where: { $0.id == contactID }) else { return }
        navigationPath.append(contact)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        vm.fetch()
    }
}
```

**Step 2: Make Contact conform to Hashable**

Add to `Models/Contact+CoreData.swift`:

```swift
extension Contact: Hashable {
    public static func == (lhs: Contact, rhs: Contact) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

**Step 3: Build and run**

`Cmd+R`. Schedule a reminder, lock the device (simulator: Device → Lock), wait for notification to fire, tap it → verify app opens directly to that contact.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: notification deep-link opens contact detail directly"
```

---

### Task 12: Final Polish & Edge Cases

**Files:**
- Modify: `Views/ContactListView.swift`
- Modify: `Views/ContactDetailView.swift`

**Step 1: Add empty state to contact list**

In `ContactListView.swift`, wrap the `List` with a check:

```swift
if vm.contacts.isEmpty {
    ContentUnavailableView(
        vm.searchText.isEmpty ? "No Contacts Yet" : "No Results",
        systemImage: "person.crop.circle.badge.plus",
        description: Text(vm.searchText.isEmpty ? "Tap + to add your first contact." : "Try a different search.")
    )
} else {
    // existing List...
}
```

**Step 2: Add swipe-to-call and swipe-to-email actions in ContactDetailView**

In the "Contact Info" section of `ContactDetailView.swift`, make email and phone tappable:

```swift
// Replace DetailRow for email with:
if !vm.email.isEmpty, let url = URL(string: "mailto:\(vm.email)") {
    Link(destination: url) {
        DetailRow(label: "Email", value: vm.email)
    }
}
// Replace DetailRow for phone with:
if !vm.phone.isEmpty, let url = URL(string: "tel:\(vm.phone.filter { $0.isNumber })") {
    Link(destination: url) {
        DetailRow(label: "Phone", value: vm.phone)
    }
}
```

**Step 3: Build and run full flow**

`Cmd+R`. Run through the complete flow:
1. Tap + → Scan Card (on device) or Add Manually
2. Fill/correct fields → Save
3. Open contact → edit notes (voice + text) → save
4. Set a reminder → verify badge on list row
5. Search for the contact by name → verify it appears
6. Swipe to delete → verify it's removed

**Step 4: Final commit**

```bash
git add .
git commit -m "feat: empty state, tappable email/phone links, final polish"
```

---

## Testing Summary

| Test Class                   | Coverage                                         |
|------------------------------|--------------------------------------------------|
| `CardTextParserTests`        | Email, phone, name, title, company extraction    |
| `PersistenceControllerTests` | Create, read, search, delete contacts            |
| `NotificationServiceTests`   | Request identifier, content title with name      |

Run all tests: `Cmd+U` in Xcode.

---

## Done Checklist

- [ ] Xcode project builds with 0 errors
- [ ] All unit tests pass
- [ ] Card scanning works on physical device
- [ ] Voice-to-text works on physical device
- [ ] Reminders fire and deep-link correctly
- [ ] Search filters in real-time
- [ ] Empty state shows when no contacts
- [ ] Swipe-to-delete works
