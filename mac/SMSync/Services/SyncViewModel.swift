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
    private var pollTimer: Timer?
    private var isPolling = false
    private var retryWorkItem: DispatchWorkItem?

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
        // Keep the current status if we already have a device and an active
        // connection; "searching" should only appear when nothing is connected.
        if currentDevice != nil {
            discovery.startDiscovery()
            return
        }
        connectionState = .discovering
        discovery.startDiscovery()
        tryConnectLastKnownDevice()
    }

    private func tryConnectLastKnownDevice() {
        guard currentDevice == nil,
              let host = pairingManager.lastKnownHost else { return }

        let device = BonjourDiscovery.DiscoveredDevice(
            name: pairingManager.pairedDeviceName ?? "Android Phone",
            hostName: host,
            port: pairingManager.lastKnownPort
        )
        connectToDevice(device)
    }

    private func connectToDevice(_ device: BonjourDiscovery.DiscoveredDevice) {
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
        connectToDevice(device)
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

                await MainActor.run {
                    self.messagesSynced = count
                    self.lastSyncDate = Date()
                    self.connectionState = .connected
                    self.pairingManager.saveLastKnown(host: device.hostName, port: device.port)
                }
                connectWebSocket(host: device.hostName, port: device.port)
                startReconnectPoll()
                await fetchContactsIfNeeded()
            } catch {
                await MainActor.run {
                    self.connectionState = .error("Sync failed: \(error.localizedDescription)")
                }
                self.scheduleReconnectRetry()
            }
        }
    }

    private func scheduleReconnectRetry() {
        retryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.pairingManager.isPaired else { return }
            self.currentDevice = nil
            self.startDiscovery()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func fetchContactsIfNeeded() async {
        guard ContactResolver.shared.phoneContactCount == 0 else { return }
        do {
            let contacts = try await syncClient.fetchContacts()
            await MainActor.run {
                ContactResolver.shared.setPhoneContacts(contacts.contacts)
            }
        } catch {
            print("Contact fetch failed: \(error.localizedDescription)")
        }
    }

    private func connectWebSocket(host: String, port: Int) {
        webSocketManager.connect(host: host, port: port, onMessage: { [weak self] message in
            let database = self?.database
            Task {
                await database?.insertMessages([message])
                await MainActor.run {
                    self?.messagesSynced += 1
                }
            }
        }, onReconnected: { [weak self] in
            guard let self else { return }
            Task {
                let since = self.database.latestMessageDate()
                do {
                    let response = try await self.syncClient.fetchSMSSince(timestamp: since)
                    guard !response.messages.isEmpty else { return }
                    await self.database.insertMessages(response.messages)
                    await MainActor.run {
                        self.messagesSynced += response.messages.count
                    }
                } catch {
                    print("Reconnect catch-up failed: \(error.localizedDescription)")
                }
            }
        })
    }

    private func startReconnectPoll() {
        stopReconnectPoll()
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.pollForNewMessages() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopReconnectPoll() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPolling = false
    }

    private func pollForNewMessages() async {
        guard !isPolling, currentDevice != nil else { return }
        isPolling = true
        defer { isPolling = false }

        let since = database.latestMessageDate()
        do {
            let response = try await syncClient.fetchSMSSince(timestamp: since)
            await MainActor.run {
                self.lastSyncDate = Date()
                // A successful poll proves the link is alive — reflect that.
                if case .connected = self.connectionState {
                    // already connected
                } else if case .syncing = self.connectionState {
                    // mid-sync, leave it alone
                } else {
                    self.connectionState = .connected
                }
            }
            if !response.messages.isEmpty {
                await database.insertMessages(response.messages)
                await MainActor.run {
                    self.messagesSynced = self.database.latestMessageCount()
                }
            }
        } catch {
            print("Poll failed: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        webSocketManager.disconnect()
        stopReconnectPoll()
        discovery.stopDiscovery()
        currentDevice = nil
        connectionState = .disconnected
    }

    func resetAfterCacheClear() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        messagesSynced = 0
        lastSyncDate = nil
        connectionState = .disconnected
        currentDevice = nil
        webSocketManager.disconnect()
        stopReconnectPoll()
        discovery.stopDiscovery()
        SMSDatabase.shared.refreshConversations()
    }

    func unpair() {
        pairingManager.unpair()
        disconnect()
    }
}