import Foundation

struct ChatMessage: Codable, Identifiable {
    var id: String
    var role: MessageRole
    var content: String
    var timestamp: Date

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID().uuidString, role: .user, content: text, timestamp: Date())
    }

    static func assistant(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID().uuidString, role: .assistant, content: text, timestamp: Date())
    }

    static func system(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID().uuidString, role: .system, content: text, timestamp: Date())
    }
}

enum MessageRole: String, Codable {
    case user, assistant, system
}
