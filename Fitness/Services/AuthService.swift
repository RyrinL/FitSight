import Foundation
import CryptoKit

// MARK: - Protocol

// ObservableObject removed so the protocol can be used as `any AuthServiceProtocol`.
// AppViewModel owns all @Published auth state; services just execute operations.
protocol AuthServiceProtocol {
    var currentUser: AppUser? { get }
    var isAuthenticated: Bool { get }
    func signIn(email: String, password: String) async throws -> AppUser
    func signUp(email: String, password: String) async throws -> AppUser
    func signOut() throws
    func deleteAccount() async throws
}

struct AppUser: Equatable {
    let uid: String
    let email: String
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case emailDomainNotAllowed
    case networkUnavailable
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:    return "Email or password is incorrect."
        case .emailAlreadyInUse:     return "An account with this email already exists."
        case .weakPassword:          return "Password must be at least 6 characters."
        case .emailDomainNotAllowed: return "Please sign up with a Gmail, Yahoo, Outlook, or iCloud address."
        case .networkUnavailable:    return "No network connection."
        case .unknown(let msg):      return msg
        }
    }
}

// MARK: - Allowed sign-up domains

enum EmailDomainPolicy {
    static let allowed: Set<String> = [
        "gmail.com",
        "yahoo.com", "yahoo.co.uk", "yahoo.com.au",
        "outlook.com", "hotmail.com", "live.com",
        "icloud.com", "me.com",
        "protonmail.com", "proton.me",
    ]

    static func isAllowed(_ email: String) -> Bool {
        let domain = email.lowercased().components(separatedBy: "@").last ?? ""
        return allowed.contains(domain)
    }
}

// MARK: - Local implementation (no Firebase required)
// Replace with FirebaseAuthService once Firebase SDK is added via SPM:
// https://github.com/firebase/firebase-ios-sdk  package: FirebaseAuth

final class LocalAuthService: AuthServiceProtocol {
    @Published private(set) var currentUser: AppUser?

    var isAuthenticated: Bool { currentUser != nil }

    private let key = "fitsight_local_accounts"
    private let sessionKey = "fitsight_session_uid"

    init() {
        if let uid = UserDefaults.standard.string(forKey: sessionKey),
           let accounts = loadAccounts(),
           let stored = accounts[uid] {
            currentUser = AppUser(uid: uid, email: stored.email)
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        guard let accounts = loadAccounts() else { throw AuthError.invalidCredentials }
        guard let stored = accounts.values.first(where: { $0.email == email.lowercased() }) else {
            throw AuthError.invalidCredentials
        }
        guard stored.passwordHash == hash(password) else { throw AuthError.invalidCredentials }
        let user = AppUser(uid: stored.uid, email: stored.email)
        UserDefaults.standard.set(stored.uid, forKey: sessionKey)
        currentUser = user
        return user
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        guard password.count >= 6 else { throw AuthError.weakPassword }
        var accounts = loadAccounts() ?? [:]
        guard !accounts.values.contains(where: { $0.email == email.lowercased() }) else {
            throw AuthError.emailAlreadyInUse
        }
        let uid = UUID().uuidString
        accounts[uid] = StoredAccount(uid: uid, email: email.lowercased(), passwordHash: hash(password))
        saveAccounts(accounts)
        let user = AppUser(uid: uid, email: email.lowercased())
        UserDefaults.standard.set(uid, forKey: sessionKey)
        currentUser = user
        return user
    }

    func signOut() throws {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        currentUser = nil
    }

    func deleteAccount() async throws {
        guard let uid = currentUser?.uid else { return }
        var accounts = loadAccounts() ?? [:]
        accounts.removeValue(forKey: uid)
        saveAccounts(accounts)
        try signOut()
    }

    private func hash(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private struct StoredAccount: Codable {
        let uid: String
        let email: String
        let passwordHash: String
    }

    private func loadAccounts() -> [String: StoredAccount]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([String: StoredAccount].self, from: data)
    }

    private func saveAccounts(_ accounts: [String: StoredAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
