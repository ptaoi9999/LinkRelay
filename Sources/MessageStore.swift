import Foundation

public struct RelayMessage: Identifiable, Codable, Hashable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
    public let sender: String
    public var hopCount: Int
    
    public init(id: UUID = UUID(), text: String, timestamp: Date = Date(), sender: String, hopCount: Int = 1) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.sender = sender
        self.hopCount = hopCount
    }
}

public class MessageStore: ObservableObject {
    @Published public var messages: [RelayMessage] = []
    private var receivedIds = Set<UUID>()
    
    public init() {}
    
    @discardableResult
    public func addMessage(_ message: RelayMessage) -> Bool {
        guard !receivedIds.contains(message.id) else {
            return false // Already processed
        }
        receivedIds.insert(message.id)
        DispatchQueue.main.async {
            self.messages.append(message)
        }
        return true
    }
    
    public func hasMessage(id: UUID) -> Bool {
        return receivedIds.contains(id)
    }
}
