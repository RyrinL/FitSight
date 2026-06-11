// MARK: - CrashlyticsService
// Active when FirebaseCrashlytics is linked via SPM.
// SPM: https://github.com/firebase/firebase-ios-sdk  target: FirebaseCrashlytics
//
// Also requires a build phase run script:
//   "${PODS_ROOT}/FirebaseCrashlytics/run" (CocoaPods) OR
//   add the Crashlytics upload-symbols script in Build Phases (SPM).

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum CrashlyticsService {

    /// Call after sign-in so crash reports are tied to a user.
    static func setUser(uid: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(uid)
        #endif
    }

    /// Record a non-fatal error with optional context string.
    static func record(_ error: Error, context: String? = nil) {
        #if canImport(FirebaseCrashlytics)
        if let context {
            Crashlytics.crashlytics().log(context)
        }
        Crashlytics.crashlytics().record(error: error)
        #endif
    }

    /// Append a breadcrumb message to the crash log.
    static func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
    }

    /// Set an arbitrary key-value pair visible in the Crashlytics dashboard.
    static func set(key: String, value: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
}
