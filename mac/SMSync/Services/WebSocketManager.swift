import Foundation
import Combine

class WebSocketManager: ObservableObject {
    @Published var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onMessageReceived: ((SMSSyncClient.SMSMessageJSON) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    func connect(host: String, port: Int, onMessage: @escaping (SMSSyncClient.SMSMessageJSON) -> Void) {
        onMessageReceived = onMessage
        let url = URL(string: "ws://\(host):\(port)/ws")!
        session = URLSession(configuration: .default)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        listenForMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.listenForMessages()
            case .failure(let error):
                print("WebSocket error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
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
