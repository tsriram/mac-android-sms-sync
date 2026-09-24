import Foundation

class ContactResolver: ObservableObject {
    static let shared = ContactResolver()

    @Published var phoneContactCache: [String: String] = [:]
    @Published private(set) var phoneContactCount = 0

    private var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SMSync", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("contact-cache.json")
    }

    init() {
        loadCache()
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
        saveCache()
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

    private func normalizePhoneNumber(_ number: String) -> String {
        let digits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digits.count >= 10 {
            return String(digits.suffix(10))
        }
        return digits
    }

    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(phoneContactCache)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            print("Failed to save contact cache: \(error)")
        }
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        do {
            let cache = try JSONDecoder().decode([String: String].self, from: data)
            phoneContactCache = cache
            phoneContactCount = cache.count
        } catch {
            print("Failed to load contact cache: \(error)")
        }
    }
}