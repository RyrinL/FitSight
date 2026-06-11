import SwiftUI

// Firebase initialisation — active once the SPM packages are linked.
// Required packages: FirebaseCore, FirebaseAuth, FirebaseFirestore,
//                    FirebaseCrashlytics, FirebaseAnalytics
// Add via Xcode → File → Add Package Dependencies →
//   https://github.com/firebase/firebase-ios-sdk
// Then add GoogleService-Info.plist (downloaded from Firebase console) to the app target.
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct FitSightApp: App {

    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
