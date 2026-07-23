import Foundation
import ObjectiveC

/// Enables switching the app's display language at runtime, independent of
/// the device's system language — standard iOS practice is to rely on
/// Settings > Language & Region, but this app also needs an in-app override
/// so users aren't forced to change their whole phone's language just to
/// use FaisTrack in Arabic (or vice versa).
///
/// Implementation note: NSLocalizedString always reads from whichever
/// .lproj bundle iOS thinks is "current" based on system language. To
/// override that, we swap Bundle.main's class to a subclass that returns
/// strings from our chosen language bundle instead — a well-established
/// technique for in-app language switching without an app restart.
private var associatedBundleKey: UInt8 = 0

class LocalizationManager {
    static let shared = LocalizationManager()
    private let languageDefaultsKey = "AppSelectedLanguage"

    private init() {
        Bundle.setLanguage(currentLanguage)
    }

    var currentLanguage: String {
        UserDefaults.standard.string(forKey: languageDefaultsKey) ?? Self.systemPreferredLanguage()
    }

    func setLanguage(_ language: String) {
        UserDefaults.standard.set(language, forKey: languageDefaultsKey)
        Bundle.setLanguage(language)
    }

    private static func systemPreferredLanguage() -> String {
        let code = Locale.preferredLanguages.first ?? "en"
        if code.hasPrefix("ar") { return "ar" }
        if code.hasPrefix("es") { return "es" }
        return "en"
    }
}

private final class OverrideBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let languageBundle = objc_getAssociatedObject(self, &associatedBundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return languageBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

private extension Bundle {
    static func setLanguage(_ language: String) {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else { return }

        if object_getClass(Bundle.main) != OverrideBundle.self {
            object_setClass(Bundle.main, OverrideBundle.self)
        }
        objc_setAssociatedObject(Bundle.main, &associatedBundleKey, languageBundle, .OBJC_ASSOCIATION_RETAIN)
    }
}

