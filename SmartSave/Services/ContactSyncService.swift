@preconcurrency import Contacts
import Foundation

struct ContactSyncService {
    private static let groupName = "SmartSave"
    private nonisolated(unsafe) static let store = CNContactStore()

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
        let allGroups = try store.groups(matching: nil)
        if let existing = allGroups.first(where: { $0.name == groupName }) {
            return existing
        }

        let newGroup = CNMutableGroup()
        newGroup.name = groupName
        let saveRequest = CNSaveRequest()
        saveRequest.add(newGroup, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

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

        cnContact.note = buildStructuredNote(
            conversationNotes: conversationNotes,
            nextSteps: nextSteps,
            followUpDate: followUpDate
        )

        let saveRequest = CNSaveRequest()
        saveRequest.add(cnContact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

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
        let allGroups = try store.groups(matching: nil)
        guard let group = allGroups.first(where: { $0.name == groupName }) else {
            return []
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
