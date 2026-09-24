import Foundation
import Combine

class WebSocketManager: ObservableObject {
    @Published var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onMessageReceived: ((SMSSyncClient.SMSMessageJSON) -> Void)?
    private var onReconnected: (() -> Void)?
    private var reconnectTimer: DispatchSourceTimer?
    private var pingTimer: DispatchSourceTimer?
    private var hasConnectedOnce = false

    private(set) var host: String?
    private(set) var port: Int?

    func connect(host: String, port: Int,
                 onMessage: @escaping (SMSSyncClient.SMSMessageJSON) -> Void,
                 onReconnected: (() -> Void)? = nil) {
        disconnectInternal()
        onMessageReceived = onMessage
        self.onReconnected = onReconnected
        self.host = host
        self.port = port
        hasConnectedOnce = false
        openSocket(host: host, port: port)
    }

    private func openSocket(host: String, port: Int) {
        let url = URL(string: "ws://\(host):\(port)/ws")!
        session = URLSession(configuration: .default)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        listenForMessages()
        startPing()
        if hasConnectedOnce {
            onReconnected?()
        }
        hasConnectedOnce = true
    }

    func disconnect() {
        disconnectInternal()
        host = nil
        port = nil
    }

    private func disconnectInternal() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
        pingTimer?.cancel()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session = nil
        isConnected = false
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.listenForMessages()
            case .failure(let error):
                print("WebSocket error: \(error)")
                DispatchQueue.main.async {
                    guard self.isConnected else { return }
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard host != nil, port != nil else { return }
        reconnectTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3)
        timer.setEventHandler { [weak self] in
            timer.cancel()
            guard let self, let host = self.host, let port = self.port else { return }
            self.openSocket(host: host, port: port)
        }
        reconnectTimer = timer
        timer.resume()
    }

    private func startPing() {
        pingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            guard let self, self.isConnected else { return }
            self.webSocketTask?.sendPing { error in
                if let error = error {
                    print("Ping failed: \(error)")
                    DispatchQueue.main.async {
                        guard self.isConnected else { return }
                        self.isConnected = false
                        self.scheduleReconnect()
                    }
                }
            }
        }
        pingTimer = timer
        timer.resume()
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String,
              event == "new_sms",
              let messageData = json["data"] else {
            return
        }

        let jsonData = try? JSONSerialization.data(withJSONObject: messageData)
        if let jsonData = jsonData,
           let message = try? JSONDecoder().decode(SMSSyncClient.SMSMessageJSON.self, from: jsonData) {
            DispatchQueue.main.async {
                self.onMessageReceived?(message)
            }
        }
    }

    func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("Ping failed: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }
}