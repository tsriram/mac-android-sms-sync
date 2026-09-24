import Foundation
import Contacts

class ContactResolver: ObservableObject {
    static let shared = ContactResolver()

    @Published var phoneContactCache: [String: String] = [:]
    @Published private(set) var phoneContactCount = 0

    private let contactStore = CNContactStore()

    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    func setPhoneContacts(_ contacts: [SMSSyncClient.ContactJSON]) {
        if contacts.isEmpty { return }
        var cache: [String: String] = [:]
        for contact in contacts {
            let normalized = normalizePhoneNumber(contact.number)
            if !normalized.isEmpty && !contact.name.isEmpty {
                cache[normalized] = contact.name
            }
        }
        phoneContactCache = cache
        phoneContactCount = cache.count
    }

    func resolveAllContacts() {
        switch authorizationStatus {
        case .notDetermined:
            contactStore.requestAccess(for: .contacts) { [weak self] granted, _ in
                if granted {
                    self?.buildMacCache()
                }
            }
        case .authorized:
            buildMacCache()
        default:
            print("Contacts access denied or restricted, skipping Mac name resolution")
        }
    }

    private func buildMacCache() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let keysToFetch = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]

            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var cache: [String: String] = [:]

            do {
                try self.contactStore.enumerateContacts(with: request) { contact, _ in
                    let name = self.displayName(for: contact)
                    for phoneNumber in contact.phoneNumbers {
                        let number = phoneNumber.value.stringValue
                        let normalized = self.normalizePhoneNumber(number)
                        if !normalized.isEmpty && !name.isEmpty {
                            cache[normalized] = name
                        }
                    }
                }
            } catch {
                print("Failed to fetch contacts: \(error)")
            }

            DispatchQueue.main.async {
                if self.phoneContactCache.isEmpty {
                    self.phoneContactCache = cache
                    self.phoneContactCount = cache.count
                }
            }
        }
    }

    func lookupName(for phoneNumber: String) -> String? {
        let normalized = normalizePhoneNumber(phoneNumber)
        return phoneContactCache[normalized]
    }

    func displayName(for phoneNumber: String?) -> String {
        guard let phoneNumber else { return "Unknown" }
        return lookupName(for: phoneNumber) ?? friendlyPhoneNumber(phoneNumber)
    }

    func friendlyPhoneNumber(_ number: String) -> String {
        let digits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard !digits.isEmpty else { return number }

        if digits.count == 10 {
            return String(format: "(%@) %@-%@",
                          String(digits.prefix(3)),
                          String(digits.dropFirst(3).prefix(3)),
                          String(digits.dropFirst(6)))
        }
        if digits.count == 12 && digits.hasPrefix("91") {
            return "+91 " + String(format: "%@ %@ %@",
                                   String(digits.dropFirst(2).prefix(3)),
                                   String(digits.dropFirst(5).prefix(3)),
                                   String(digits.dropFirst(8).prefix(4)))
        }
        return number
    }

    private func displayName(for contact: CNContact) -> String {
        let personName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        if !personName.isEmpty { return personName }
        return contact.organizationName
    }

    private func normalizePhoneNumber(_ number: String) -> String {
        let digits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digits.count >= 10 {
            return String(digits.suffix(10))
        }
        return digits
    }
}