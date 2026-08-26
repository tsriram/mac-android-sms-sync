import Foundation

class SMSSyncClient: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?

    private var baseURL: String?
    private let session = URLSession.shared

    struct SMSMessageJSON: Codable {
        let id: Int64
        let address: String
        let body: String
        let date: Int64
        let type: Int
        let read: Bool
    }

    struct SMSResponse: Codable {
        let messages: [SMSMessageJSON]
        let total: Int
        let hasMore: Bool
    }

    struct DeviceInfo: Codable {
        let deviceName: String
        let totalSMS: Int
        let lastMessageTimestamp: Int64
        let version: String
    }

    struct PairResponse: Codable {
        let paired: Bool
        let deviceToken: String?
        let error: String?
    }

    func configure(host: String, port: Int) {
        baseURL = "http://\(host):\(port)"
    }

    func fetchDeviceInfo() async throws -> DeviceInfo {
        guard let url = URL(string: "\(baseURL!)/api/info") else {
            throw SyncError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(DeviceInfo.self, from: data)
    }

    func initPairing(pin: String) async throws -> PairResponse {
        guard let url = URL(string: "\(baseURL!)/api/pair?pin=\(pin)") else {
            throw SyncError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(PairResponse.self, from: data)
    }

    func fetchAllSMS(offset: Int = 0, limit: Int = 500) async throws -> SMSResponse {
        guard let url = URL(string: "\(baseURL!)/api/sms?offset=\(offset)&limit=\(limit)") else {
            throw SyncError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(SMSResponse.self, from: data)
    }

    func fetchSMSSince(timestamp: Int64) async throws -> SMSResponse {
        guard let url = URL(string: "\(baseURL!)/api/sms?since=\(timestamp)") else {
            throw SyncError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(SMSResponse.self, from: data)
    }

    enum SyncError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
    }
}
