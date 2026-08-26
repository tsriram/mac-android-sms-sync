import Foundation
import Contacts

class ContactResolver: ObservableObject {
    @Published var contactCache: [String: String] = [:]

    private let contactStore = CNContactStore()

    func resolveAllContacts() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let keysToFetch = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]

            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var cache: [String: String] = [:]

            do {
                try self.contactStore.enumerateContacts(with: request) { contact, _ in
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
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
                self.contactCache = cache
            }
        }
    }

    func lookupName(for phoneNumber: String) -> String? {
        let normalized = normalizePhoneNumber(phoneNumber)
        return contactCache[normalized]
    }

    private func normalizePhoneNumber(_ number: String) -> String {
        let digits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digits.count >= 10 {
            return String(digits.suffix(10))
        }
        return digits
    }
}
