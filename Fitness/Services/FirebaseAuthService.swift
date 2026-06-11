// MARK: - FirebaseAuthService
// Active when FirebaseAuth is linked via SPM.
// SPM: https://github.com/firebase/firebase-ios-sdk  target: FirebaseAuth

#if canImport(FirebaseAuth)
import FirebaseAuth
import Foundation

final class FirebaseAuthService: AuthServiceProtocol {

    var currentUser: AppUser? {
        Auth.auth().currentUser.map { AppUser(uid: $0.uid, email: $0.email ?? "") }
    }

    var isAuthenticated: Bool { Auth.auth().currentUser != nil }

    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return AppUser(uid: result.user.uid, email: result.user.email ?? email)
        } catch {
            throw map(error)
        }
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        guard password.count >= 6 else { throw AuthError.weakPassword }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return AppUser(uid: result.user.uid, email: result.user.email ?? email)
        } catch {
            throw map(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
    }

    // Maps Firebase NSError codes to typed AuthError values.
    private func map(_ error: Error) -> AuthError {
        let code = (error as NSError).code
        switch code {
        case 17009, 17011: return .invalidCredentials   // wrong password, user not found
        case 17007:        return .emailAlreadyInUse
        case 17026:        return .weakPassword
        case 17020:        return .networkUnavailable
        default:           return .unknown(error.localizedDescription)
        }
    }
}
#endif
