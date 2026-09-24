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
        stopDiscovery()
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
        browser?.searchForServices(ofType: "_smsync._tcp.", inDomain: "local.")
    }

    func stopDiscovery() {
        guard let browser = browser else { return }
        browser.stop()
        self.browser = nil
        serviceDelegate = nil
        foundServices.removeAll()
        isScanning = false
    }

    private func handleServiceFound(_ service: NetService) {
        guard !foundServices.contains(where: { $0.name == service.name }) else { return }
        foundServices.append(service)
        service.delegate = serviceDelegate
        service.resolve(withTimeout: 5)
    }

    private func handleServiceResolved(_ service: NetService) {
        let port = service.port
        let name = service.name

        // Prefer an actual IPv4 address from the resolved record when available.
        var address: String? = nil
        if let addresses = service.addresses, !addresses.isEmpty {
            for data in addresses {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                data.withUnsafeBytes { rawBuffer in
                    let sockaddr = rawBuffer.bindMemory(to: sockaddr.self)
                    getnameinfo(
                        sockaddr.baseAddress,
                        socklen_t(rawBuffer.count),
                        &host,
                        socklen_t(host.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                }
                let hostStr = String(cString: host)
                if isIPv4(hostStr) {
                    address = hostStr
                    break
                } else if address == nil {
                    address = hostStr
                }
            }
        }

        let host = address ?? service.hostName
        guard let resolvedHost = host, !resolvedHost.isEmpty else {
            print("Bonjour resolve: no usable address for \(name)")
            return
        }

        discoveredDevice = DiscoveredDevice(
            name: name,
            hostName: resolvedHost,
            port: port
        )
    }

    private func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { Int($0) != nil && (0...255).contains(Int($0)!)
        }
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