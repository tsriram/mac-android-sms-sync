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
    private var serviceDelegate: ServiceDelegate?
    private var foundServices: [NetService] = []

    func startDiscovery() {
        isScanning = true
        browser = NetServiceBrowser()
        serviceDelegate = ServiceDelegate()
        serviceDelegate?.onServiceFound = { [weak self] service in
            DispatchQueue.main.async {
                self?.handleServiceFound(service)
            }
        }
        serviceDelegate?.onServiceResolved = { [weak self] service in
            DispatchQueue.main.async {
                self?.handleServiceResolved(service)
            }
        }
        browser?.delegate = serviceDelegate
        browser?.searchForServices(ofType: "_smsync._tcp.", inDomain: "")
    }

    func stopDiscovery() {
        browser?.stop()
        browser = nil
        serviceDelegate = nil
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

class ServiceDelegate: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    var onServiceFound: ((NetService) -> Void)?
    var onServiceResolved: ((NetService) -> Void)?

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        onServiceFound?(service)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("Bonjour search failed: \(errorDict)")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        onServiceResolved?(sender)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("Bonjour resolve failed: \(errorDict)")
    }
}
