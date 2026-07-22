import Foundation

public struct RelayMessage: Identifiable, Codable, Hashable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
    public let sender: String
    public var hopCount: Int
    public let channel: String // "open", "family", "dm"
    public let recipient: String?
    
    public init(id: UUID = UUID(), text: String, timestamp: Date = Date(), sender: String, hopCount: Int = 1, channel: String = "open", recipient: String? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.sender = sender
        self.hopCount = hopCount
        self.channel = channel
        self.recipient = recipient
    }
}

public class MessageStore: ObservableObject {
    @Published public var openMessages: [RelayMessage] = []
    @Published public var familyMessages: [RelayMessage] = []
    @Published public var dmMessages: [RelayMessage] = []
    
    private var receivedIds = Set<UUID>()
    
    public init() {
        loadMessages()
    }
    
    @discardableResult
    public func addMessage(_ message: RelayMessage) -> Bool {
        guard !receivedIds.contains(message.id) else {
            return false // Already processed
        }
        receivedIds.insert(message.id)
        DispatchQueue.main.async {
            if message.channel == "family" {
                self.familyMessages.append(message)
            } else if message.channel == "dm" {
                self.dmMessages.append(message)
            } else {
                self.openMessages.append(message)
            }
            self.saveMessages()
        }
        return true
    }
    
    public func hasMessage(id: UUID) -> Bool {
        return receivedIds.contains(id)
    }
    
    private func saveMessages() {
        let encoder = JSONEncoder()
        if let encodedOpen = try? encoder.encode(openMessages) {
            UserDefaults.standard.set(encodedOpen, forKey: "LinkRelay_openMessages")
        }
        if let encodedFamily = try? encoder.encode(familyMessages) {
            UserDefaults.standard.set(encodedFamily, forKey: "LinkRelay_familyMessages")
        }
        if let encodedDM = try? encoder.encode(dmMessages) {
            UserDefaults.standard.set(encodedDM, forKey: "LinkRelay_dmMessages")
        }
        if let encodedIds = try? encoder.encode(Array(receivedIds)) {
            UserDefaults.standard.set(encodedIds, forKey: "LinkRelay_receivedIds")
        }
    }
    
    private func loadMessages() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "LinkRelay_openMessages"),
           let decoded = try? decoder.decode([RelayMessage].self, from: data) {
            openMessages = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "LinkRelay_familyMessages"),
           let decoded = try? decoder.decode([RelayMessage].self, from: data) {
            familyMessages = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "LinkRelay_dmMessages"),
           let decoded = try? decoder.decode([RelayMessage].self, from: data) {
            dmMessages = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "LinkRelay_receivedIds"),
           let decoded = try? decoder.decode([UUID].self, from: data) {
            receivedIds = Set(decoded)
        }
    }
}
