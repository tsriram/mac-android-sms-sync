import Foundation
import Combine

class BonjourDiscovery: ObservableObject {
    @Published var discoveredDevice: DiscoveredDevice?
    @Published var isScanning = false

    struct DiscoveredDevice {
        let name: String
        let hostName: String
        let port: Int
    }

    private var browser: NetServiceBrowser?
    private var foundServices: [NetService] = []

    func startDiscovery() {
        isScanning = true
        browser = NetServiceBrowser()
        browser?.delegate = ServiceDelegate.shared
        browser?.searchForServices(ofType: "_smsync._tcp.", inDomain: "")

        ServiceDelegate.shared.onServiceFound = { [weak self] service in
            DispatchQueue.main.async {
                self?.handleServiceFound(service)
            }
        }
        ServiceDelegate.shared.onServiceResolved = { [weak self] service in
            DispatchQueue.main.async {
                self?.handleServiceResolved(service)
            }
        }
    }

    func stopDiscovery() {
        browser?.stop()
        browser = nil
        isScanning = false
        foundServices.removeAll()
    }

    private func handleServiceFound(_ service: NetService) {
        guard !foundServices.contains(where: { $0.name == service.name }) else { return }
        foundServices.append(service)
        service.resolve(withTimeout: 5000)
    }

    private func handleServiceResolved(_ service: NetService) {
        guard let hostName = service.hostName else { return }
        discoveredDevice = DiscoveredDevice(
            name: service.name,
            hostName: hostName,
            port: service.port
        )
    }
}

class ServiceDelegate: NSObject, NetServiceDelegate {
    static let shared = ServiceDelegate()

    var onServiceFound: ((NetService) -> Void)?
    var onServiceResolved: ((NetService) -> Void)?

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing Bool) {
        onServiceFound?(service)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        onServiceResolved?(sender)
    }
}
