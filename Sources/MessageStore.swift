import Foundation

public struct RelayMessage: Identifiable, Codable, Hashable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
    public let sender: String
    public var hopCount: Int
    public let channel: String // "open" or "family"
    
    public init(id: UUID = UUID(), text: String, timestamp: Date = Date(), sender: String, hopCount: Int = 1, channel: String = "open") {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.sender = sender
        self.hopCount = hopCount
        self.channel = channel
    }
}

public class MessageStore: ObservableObject {
    @Published public var openMessages: [RelayMessage] = []
    @Published public var familyMessages: [RelayMessage] = []
    
    private var receivedIds = Set<UUID>()
    
    public init() {}
    
    @discardableResult
    public func addMessage(_ message: RelayMessage) -> Bool {
        guard !receivedIds.contains(message.id) else {
            return false // Already processed
        }
        receivedIds.insert(message.id)
        DispatchQueue.main.async {
            if message.channel == "family" {
                self.familyMessages.append(message)
            } else {
                self.openMessages.append(message)
            }
        }
        return true
    }
    
    public func hasMessage(id: UUID) -> Bool {
        return receivedIds.contains(id)
    }
}
