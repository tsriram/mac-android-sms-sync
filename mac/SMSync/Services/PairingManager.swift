import Foundation
import Security

class PairingManager: ObservableObject {
    @Published var isPaired = false
    @Published var pairedDeviceName: String?
    @Published var showPairingSheet = false
    @Published var generatedPin: String?

    private let serviceName = "com.smsync.pairing"

    func generatePin() -> String {
        let pin = String(format: "%06d", Int.random(in: 0...999999))
        generatedPin = pin
        return pin
    }

    func completePairing(deviceToken: String, deviceName: String) {
        storeInKeychain(key: "deviceToken", value: deviceToken)
        storeInKeychain(key: "deviceName", value: deviceName)
        isPaired = true
        pairedDeviceName = deviceName
        showPairingSheet = false
        generatedPin = nil
    }

    func checkPairingStatus() {
        if let _ = loadFromKeychain(key: "deviceToken"),
           let name = loadFromKeychain(key: "deviceName") {
            isPaired = true
            pairedDeviceName = name
        }
    }

    func unpair() {
        deleteFromKeychain(key: "deviceToken")
        deleteFromKeychain(key: "deviceName")
        isPaired = false
        pairedDeviceName = nil
        generatedPin = nil
    }

    private func storeInKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
