import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?

    var context: CoachContext?

    private let db: any DatabaseServiceProtocol
    private let coach = AICoachService.shared

    init(db: any DatabaseServiceProtocol) { self.db = db }

    func loadHistory(uid: String) async {
        messages = (try? await db.fetchChatHistory(uid: uid)) ?? []
    }

    func send(uid: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }
        draft = ""

        let userMsg = ChatMessage.user(text)
        messages.append(userMsg)
        isGenerating = true
        errorMessage = nil

        do {
            let reply = try await coach.send(messages: messages, context: context)
            let assistantMsg = ChatMessage.assistant(reply)
            messages.append(assistantMsg)
            try? await db.saveChatHistory(messages, uid: uid)
        } catch {
            errorMessage = error.localizedDescription
            messages.removeLast()
        }
        isGenerating = false
    }

    func clearHistory(uid: String) async {
        messages = []
        try? await db.saveChatHistory([], uid: uid)
    }
}
