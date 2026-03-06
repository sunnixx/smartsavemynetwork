import SwiftUI
import Contacts

struct ContactDetailView: View {
    @StateObject private var vm: ContactDetailViewModel
    @State private var showNotes = false
    @State private var showReminderPicker = false
    @State private var showEditInfo = false
    @State private var contactSaveMessage: String?
    @State private var shareItems: [Any]?
    @State private var showFullImage = false
    @State private var showSaveOptions = false

    init(contact: Contact, onSave: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ContactDetailViewModel(contact: contact, onSave: onSave))
    }

    private var emailList: [String] {
        vm.email.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private var phoneList: [String] {
        vm.phone.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private var initials: String {
        let parts = vm.name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(vm.name.prefix(2)).uppercased()
    }

    var body: some View {
        List {
            // Header with avatar
            Section {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.accentColor.opacity(0.7), .accentColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                        Text(initials)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Text(vm.name)
                        .font(.title2.weight(.semibold))
                    if !vm.title.isEmpty || !vm.company.isEmpty {
                        Text([vm.title, vm.company].filter { !$0.isEmpty }.joined(separator: " at "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if let image = vm.cardImage {
                Section("Business Card") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        .onTapGesture { showFullImage = true }
                        .frame(maxWidth: .infinity)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Contact Info") {
                if !emailList.isEmpty {
                    ForEach(Array(emailList.enumerated()), id: \.offset) { _, email in
                        if let url = URL(string: "mailto:\(email)") {
                            Link(destination: url) {
                                Label(email, systemImage: "envelope")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                if !phoneList.isEmpty {
                    ForEach(Array(phoneList.enumerated()), id: \.offset) { _, phone in
                        if let url = URL(string: "tel:\(phone.filter { $0.isNumber })") {
                            Link(destination: url) {
                                Label(phone, systemImage: "phone")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                if emailList.isEmpty && phoneList.isEmpty {
                    Label("No contact details", systemImage: "info.circle")
                        .foregroundColor(.secondary)
                }

                Button {
                    showEditInfo = true
                } label: {
                    Label("Edit Contact Info", systemImage: "pencil")
                }
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "text.quote")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    if vm.conversationNotes.isEmpty {
                        Text("No notes yet")
                            .foregroundColor(.secondary)
                    } else {
                        Text(vm.conversationNotes)
                            .lineLimit(3)
                    }
                }
                .onTapGesture { showNotes = true }

                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    if vm.nextSteps.isEmpty {
                        Text("No next steps")
                            .foregroundColor(.secondary)
                    } else {
                        Text(vm.nextSteps)
                            .lineLimit(3)
                    }
                }
                .onTapGesture { showNotes = true }

                Button {
                    showNotes = true
                } label: {
                    Label("Edit Notes & Next Steps", systemImage: "square.and.pencil")
                }
            } header: {
                Text("Notes")
            }

            Section {
                if let date = vm.followUpDate {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(date, style: .date)
                                .font(.body)
                            Text(date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(role: .destructive) {
                        vm.followUpDate = nil
                        vm.save()
                    } label: {
                        Label("Remove Reminder", systemImage: "bell.slash")
                    }
                } else {
                    Button {
                        showReminderPicker = true
                    } label: {
                        Label("Set Follow-up Reminder", systemImage: "bell.badge")
                    }
                }
            } header: {
                Text("Reminder")
            }

            Section {
                Button {
                    showSaveOptions = true
                } label: {
                    Label("Save to Contacts", systemImage: "person.crop.circle.badge.plus")
                }

                Button {
                    shareItems = buildShareItems()
                } label: {
                    Label("Share Contact", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vm.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditInfo, onDismiss: vm.save) {
            EditContactInfoView(vm: vm)
        }
        .sheet(isPresented: $showNotes, onDismiss: vm.save) {
            NotesView(notes: $vm.conversationNotes, nextSteps: $vm.nextSteps)
        }
        .sheet(isPresented: $showReminderPicker) {
            ReminderPickerView(selectedDate: $vm.followUpDate, onConfirm: {
                showReminderPicker = false
                vm.save()
            })
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ShareSheet(items: items)
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            if let image = vm.cardImage {
                FullImageView(image: image)
            }
        }
        .confirmationDialog("Save to Contacts", isPresented: $showSaveOptions) {
            Button("Create New Contact") { saveAsNewContact() }
            Button("Add to Existing Contact") { addToExistingContact() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Contacts", isPresented: Binding(
            get: { contactSaveMessage != nil },
            set: { if !$0 { contactSaveMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactSaveMessage ?? "")
        }
    }

    // MARK: - Share

    private func buildShareItems() -> [Any] {
        [buildShareImage()]
    }

    private func buildShareImage() -> UIImage {
        let width: CGFloat = 600
        let padding: CGFloat = 24
        let contentWidth = width - padding * 2

        var lines: [(String, UIFont, UIColor)] = []
        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let bodyFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        let labelFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let labelColor = UIColor.secondaryLabel
        let textColor = UIColor.label

        lines.append((vm.name, titleFont, textColor))
        if !vm.title.isEmpty { lines.append((vm.title, bodyFont, labelColor)) }
        if !vm.company.isEmpty { lines.append((vm.company, bodyFont, labelColor)) }
        lines.append(("", bodyFont, textColor))

        for email in emailList { lines.append(("Email: \(email)", bodyFont, textColor)) }
        for phone in phoneList { lines.append(("Phone: \(phone)", bodyFont, textColor)) }

        if !vm.conversationNotes.isEmpty {
            lines.append(("", bodyFont, textColor))
            lines.append(("Notes", labelFont, labelColor))
            lines.append((vm.conversationNotes, bodyFont, textColor))
        }
        if !vm.nextSteps.isEmpty {
            lines.append(("", bodyFont, textColor))
            lines.append(("Next Steps", labelFont, labelColor))
            lines.append((vm.nextSteps, bodyFont, textColor))
        }

        var cardImageHeight: CGFloat = 0
        var scaledCardImage: UIImage?
        if let card = vm.cardImage {
            let aspect = card.size.height / card.size.width
            cardImageHeight = contentWidth * aspect
            scaledCardImage = card
        }

        var textHeight: CGFloat = 0
        for (text, font, _) in lines {
            if text.isEmpty {
                textHeight += 12
            } else {
                let rect = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font],
                    context: nil
                )
                textHeight += ceil(rect.height) + 4
            }
        }

        let totalHeight = padding + (cardImageHeight > 0 ? cardImageHeight + 16 : 0) + textHeight + padding

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight))
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))

            var y = padding

            if let card = scaledCardImage {
                card.draw(in: CGRect(x: padding, y: y, width: contentWidth, height: cardImageHeight))
                y += cardImageHeight + 16
            }

            for (text, font, color) in lines {
                if text.isEmpty { y += 12; continue }
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let rect = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                (text as NSString).draw(
                    in: CGRect(x: padding, y: y, width: contentWidth, height: ceil(rect.height)),
                    withAttributes: attrs
                )
                y += ceil(rect.height) + 4
            }
        }
    }

    // MARK: - Save to Device Contacts

    private func buildCNContact() -> CNMutableContact {
        let cnContact = CNMutableContact()
        let nameParts = vm.name.split(separator: " ", maxSplits: 1)
        cnContact.givenName = String(nameParts.first ?? "")
        if nameParts.count > 1 {
            cnContact.familyName = String(nameParts[1])
        }
        if !vm.title.isEmpty { cnContact.jobTitle = vm.title }
        if !vm.company.isEmpty { cnContact.organizationName = vm.company }

        let emails = vm.email.components(separatedBy: "\n").filter { !$0.isEmpty }
        cnContact.emailAddresses = emails.map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }
        let phones = vm.phone.components(separatedBy: "\n").filter { !$0.isEmpty }
        cnContact.phoneNumbers = phones.map {
            CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: $0))
        }
        return cnContact
    }

    private func saveAsNewContact() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            Task { @MainActor in
                guard granted else {
                    contactSaveMessage = "Please allow access to Contacts in Settings."
                    return
                }
                let cnContact = buildCNContact()
                let saveRequest = CNSaveRequest()
                saveRequest.add(cnContact, toContainerWithIdentifier: nil)
                do {
                    try store.execute(saveRequest)
                    contactSaveMessage = "\(vm.name) saved as a new contact."
                } catch {
                    contactSaveMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    private func addToExistingContact() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            Task { @MainActor in
                guard granted else {
                    contactSaveMessage = "Please allow access to Contacts in Settings."
                    return
                }
                let cnContact = buildCNContact()
                let picker = CNContactPickerHelper(contact: cnContact) { message in
                    contactSaveMessage = message
                }
                picker.present()
            }
        }
    }
}

// MARK: - Edit Contact Info Sheet

struct EditContactInfoView: View {
    @ObservedObject var vm: ContactDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Info") {
                    TextField("Name", text: $vm.name)
                    TextField("Title", text: $vm.title)
                    TextField("Company", text: $vm.company)
                    TextField("Email", text: $vm.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $vm.phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Full Screen Image Viewer

struct FullImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    private var isZoomed: Bool { lastScale > 1.05 }

    var body: some View {
        let combinedOffset = CGSize(
            width: offset.width + dragOffset.width,
            height: offset.height + dragOffset.height
        )

        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()
                        .opacity(isZoomed ? 1.0 : max(0.4, 1.0 - abs(dragOffset.height) / CGFloat(300)))

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale * lastScale)
                        .offset(combinedOffset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = value.magnification
                                }
                                .onEnded { value in
                                    let newScale = lastScale * value.magnification
                                    lastScale = max(1.0, min(newScale, 5.0))
                                    scale = 1.0
                                    if lastScale <= 1.0 { offset = .zero }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    if !isZoomed && abs(value.translation.height) > 100 {
                                        dismiss()
                                    } else if isZoomed {
                                        offset = CGSize(
                                            width: offset.width + value.translation.width,
                                            height: offset.height + value.translation.height
                                        )
                                    }
                                    dragOffset = .zero
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(duration: 0.3)) {
                                if lastScale > 1.0 {
                                    lastScale = 1.0
                                    offset = .zero
                                } else {
                                    lastScale = 2.5
                                }
                            }
                        }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: dragOffset)
    }
}

// MARK: - Contact Picker Helper

@MainActor
class CNContactPickerHelper: NSObject {
    private let contact: CNMutableContact
    private let completion: (String) -> Void
    private var hostController: UIViewController?

    init(contact: CNMutableContact, completion: @escaping (String) -> Void) {
        self.contact = contact
        self.completion = completion
    }

    func present() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            completion("Could not present contact picker.")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let picker = ContactPickerViewController(
            contact: contact,
            completion: completion
        )
        let nav = UINavigationController(rootViewController: picker)
        topVC.present(nav, animated: true)
    }
}

// MARK: - Existing Contact Picker

class ContactPickerViewController: UITableViewController {
    private let newContact: CNMutableContact
    private let completion: @MainActor (String) -> Void
    private var existingContacts: [CNContact] = []
    private let store = CNContactStore()

    init(contact: CNMutableContact, completion: @escaping @MainActor (String) -> Void) {
        self.newContact = contact
        self.completion = completion
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Contact"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        loadContacts()
    }

    private func loadContacts() {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName
        var results: [CNContact] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            results.append(contact)
        }
        existingContacts = results
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        existingContacts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let c = existingContacts[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = [c.givenName, c.familyName].joined(separator: " ").trimmingCharacters(in: .whitespaces)
        config.secondaryText = c.organizationName.isEmpty ? nil : c.organizationName
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let existing = existingContacts[indexPath.row]
        guard let mutable = existing.mutableCopy() as? CNMutableContact else { return }

        let existingEmails = Set(mutable.emailAddresses.map { $0.value as String })
        for email in newContact.emailAddresses {
            if !existingEmails.contains(email.value as String) {
                mutable.emailAddresses.append(email)
            }
        }

        let existingPhones = Set(mutable.phoneNumbers.map { $0.value.stringValue })
        for phone in newContact.phoneNumbers {
            if !existingPhones.contains(phone.value.stringValue) {
                mutable.phoneNumbers.append(phone)
            }
        }

        if mutable.jobTitle.isEmpty { mutable.jobTitle = newContact.jobTitle }
        if mutable.organizationName.isEmpty { mutable.organizationName = newContact.organizationName }

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutable)

        let name = [mutable.givenName, mutable.familyName].joined(separator: " ").trimmingCharacters(in: .whitespaces)

        do {
            try store.execute(saveRequest)
            dismiss(animated: true) { [completion] in
                Task { @MainActor in
                    completion("Info added to \(name).")
                }
            }
        } catch {
            dismiss(animated: true) { [completion] in
                Task { @MainActor in
                    completion("Failed to update: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Shared Components

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
