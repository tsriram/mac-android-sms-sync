import Foundation
import Combine

class SyncViewModel: ObservableObject {
    static let shared = SyncViewModel()

    @Published var connectionState: ConnectionState = .disconnected
    @Published var deviceName: String?
    @Published var lastSyncDate: Date?
    @Published var messagesSynced: Int = 0
    @Published var showPairingSheet = false
    @Published var generatedPin: String?
    @Published var pairingError: String?
    @Published var errorMessage: String?

    enum ConnectionState {
        case disconnected
        case discovering
        case discovered(BonjourDiscovery.DiscoveredDevice)
        case pairing
        case connected
        case syncing
        case error(String)
    }

    private let discovery = BonjourDiscovery()
    private let syncClient = SMSSyncClient()
    private let webSocketManager = WebSocketManager()
    private let pairingManager = PairingManager()
    private let database = SMSDatabase.shared
    private var cancellables = Set<AnyCancellable>()

    private var currentDevice: BonjourDiscovery.DiscoveredDevice?

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        if case .syncing = connectionState { return true }
        if case .pairing = connectionState { return true }
        return false
    }

    init() {
        pairingManager.checkPairingStatus()

        discovery.$discoveredDevice
            .compactMap { $0 }
            .removeDuplicates { lhs, rhs in
                lhs.hostName == rhs.hostName && lhs.port == rhs.port
            }
            .sink { [weak self] device in
                self?.handleDeviceDiscovered(device)
            }
            .store(in: &cancellables)
    }

    func startDiscovery() {
        connectionState = .discovering
        discovery.startDiscovery()
    }

    func stopDiscovery() {
        discovery.stopDiscovery()
    }

    func connectManually(to host: String) {
        guard !host.isEmpty else { return }
        let device = BonjourDiscovery.DiscoveredDevice(
            name: "Android Phone",
            hostName: host,
            port: 8484
        )
        stopDiscovery()
        handleDeviceDiscovered(device)
    }

    private func handleDeviceDiscovered(_ device: BonjourDiscovery.DiscoveredDevice) {
        guard currentDevice == nil || currentDevice?.hostName != device.hostName else { return }
        currentDevice = device
        connectionState = .discovered(device)
        deviceName = device.name
        syncClient.configure(host: device.hostName, port: device.port)

        if pairingManager.isPaired {
            connectAndSync()
        } else {
            startPairing()
        }
    }

    func startPairing() {
        guard let device = currentDevice else { return }
        connectionState = .pairing

        Task {
            do {
                let _ = try await syncClient.fetchDeviceInfo()
                await MainActor.run {
                    self.pairingError = nil
                    self.showPairingSheet = true
                }
            } catch {
                await MainActor.run {
                    self.pairingError = "Could not reach phone: \(error.localizedDescription)"
                }
            }
        }
    }

    func cancelPairing() {
        showPairingSheet = false
        pairingError = nil
        currentDevice = nil
        connectionState = .discovering
        startDiscovery()
    }

    func completePairing(pin: String) {
        showPairingSheet = false
        Task {
            do {
                let response = try await syncClient.initPairing(pin: pin)
                if response.paired {
                    await MainActor.run {
                        self.pairingManager.completePairing(
                            deviceToken: response.deviceToken ?? "temp",
                            deviceName: self.deviceName ?? "Unknown Device"
                        )
                        self.connectAndSync()
                    }
                } else {
                    await MainActor.run {
                        self.pairingError = response.error ?? "Pairing failed"
                        self.showPairingSheet = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.pairingError = "Pairing failed: \(error.localizedDescription)"
                    self.showPairingSheet = true
                }
            }
        }
    }

    func connectAndSync() {
        guard let device = currentDevice else { return }
        connectionState = .syncing

        Task {
            do {
                let info = try await syncClient.fetchDeviceInfo()
                await MainActor.run {
                    self.deviceName = info.deviceName
                }

                var allMessages: [SMSSyncClient.SMSMessageJSON] = []
                var offset = 0
                let limit = 500
                var hasMore = true

                while hasMore {
                    let response = try await syncClient.fetchAllSMS(offset: offset, limit: limit)
                    allMessages.append(contentsOf: response.messages)
                    hasMore = response.hasMore
                    offset += limit
                }

                let count = allMessages.count
                await database.insertMessages(allMessages)

                if let contacts = try? await syncClient.fetchContacts() {
                    await MainActor.run {
                        ContactResolver.shared.setPhoneContacts(contacts.contacts)
                    }
                }

                await MainActor.run {
                    self.messagesSynced = count
                    self.lastSyncDate = Date()
                    self.connectionState = .connected
                }
                connectWebSocket(host: device.hostName, port: device.port)
            } catch {
                await MainActor.run {
                    self.connectionState = .error("Sync failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func connectWebSocket(host: String, port: Int) {
        webSocketManager.connect(host: host, port: port) { [weak self] message in
            let database = self?.database
            Task {
                await database?.insertMessages([message])
                await MainActor.run {
                    self?.messagesSynced += 1
                }
            }
        }
    }

    func disconnect() {
        webSocketManager.disconnect()
        discovery.stopDiscovery()
        currentDevice = nil
        connectionState = .disconnected
    }

    func resetAfterCacheClear() {
        messagesSynced = 0
        lastSyncDate = nil
        connectionState = .disconnected
        currentDevice = nil
        webSocketManager.disconnect()
        discovery.stopDiscovery()
        SMSDatabase.shared.refreshConversations()
    }

    func unpair() {
        pairingManager.unpair()
        disconnect()
    }
}