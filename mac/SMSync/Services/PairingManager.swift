import Foundation

class PairingManager: ObservableObject {
    @Published var isPaired = false
    @Published var pairedDeviceName: String?
    @Published var showPairingSheet = false
    @Published var generatedPin: String?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let deviceToken = "pairing.deviceToken"
        static let deviceName = "pairing.deviceName"
        static let deviceHost = "pairing.deviceHost"
        static let devicePort = "pairing.devicePort"
    }

    var lastKnownHost: String? {
        defaults.string(forKey: Keys.deviceHost)
    }

    var lastKnownPort: Int {
        defaults.integer(forKey: Keys.devicePort) != 0 ? defaults.integer(forKey: Keys.devicePort) : 8484
    }

    func generatePin() -> String {
        let pin = String(format: "%06d", Int.random(in: 0...999999))
        generatedPin = pin
        return pin
    }

    func completePairing(deviceToken: String, deviceName: String) {
        defaults.set(deviceToken, forKey: Keys.deviceToken)
        defaults.set(deviceName, forKey: Keys.deviceName)
        isPaired = true
        pairedDeviceName = deviceName
        showPairingSheet = false
        generatedPin = nil
    }

    func checkPairingStatus() {
        if defaults.string(forKey: Keys.deviceToken) != nil,
           let name = defaults.string(forKey: Keys.deviceName) {
            isPaired = true
            pairedDeviceName = name
        }
    }

    func unpair() {
        defaults.removeObject(forKey: Keys.deviceToken)
        defaults.removeObject(forKey: Keys.deviceName)
        defaults.removeObject(forKey: Keys.deviceHost)
        defaults.removeObject(forKey: Keys.devicePort)
        isPaired = false
        pairedDeviceName = nil
        generatedPin = nil
    }

    func saveLastKnown(host: String, port: Int) {
        defaults.set(host, forKey: Keys.deviceHost)
        defaults.set(port, forKey: Keys.devicePort)
    }
}