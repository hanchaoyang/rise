import Foundation
import OSLog

// MARK: - Localization Manager

/// Singleton that manages runtime language switching.
///
/// Loads the String Catalog's compiled ``Localizable.strings`` resources into
/// an in-memory dictionary at startup and resolves lookups from that
/// dictionary at runtime, so language changes take effect immediately without
/// requiring an app restart. Also keeps `AppleLanguages` in sync so system
/// APIs such as `Locale.preferredLanguages` follow the chosen language.
/// Conforms to `Observable` so SwiftUI views automatically refresh when the
/// language changes.
@Observable
final class LocalizationManager {

    /// Shared singleton instance.
    static let shared = LocalizationManager()

    // MARK: - Supported Languages

    /// Languages available in the Settings picker.
    enum SupportedLanguage: String, CaseIterable, Identifiable {
        case english            = "en"
        case simplifiedChinese  = "zh-Hans"
        case traditionalChinese = "zh-Hant"

        var id: String { rawValue }

        /// Display name in the language itself (e.g. "English", "简体中文").
        var displayName: String {
            switch self {
            case .english:            return "English"
            case .simplifiedChinese:  return "简体中文"
            case .traditionalChinese: return "繁體中文"
            }
        }
    }

    // MARK: - Properties

    /// Currently active language. Changing this property persists the selection,
    /// updates `AppleLanguages`, and records the change in the unified log.
    var currentLanguage: SupportedLanguage {
        didSet {
            let language = currentLanguage.rawValue
            UserDefaults.standard.set(language, forKey: Constants.languageStorageKey)
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
            Logger.loc.info("Language switched to \(language, privacy: .public)")
        }
    }

    /// All languages offered in the Settings picker.
    let availableLanguages = SupportedLanguage.allCases

    /// Translation lookup table keyed by language then source key.
    private let translations: [SupportedLanguage: [String: String]]

    // MARK: - Initialization

    private init() {
        translations = Self.loadTranslations()
        if let saved = UserDefaults.standard.string(forKey: Constants.languageStorageKey),
           let language = SupportedLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            currentLanguage = .english
        }
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
    }

    /// Loads the compiled `Localizable.strings` table for every supported
    /// language. Tables that cannot be found or read are skipped — lookups
    /// then fall back to the English table.
    private static func loadTranslations() -> [SupportedLanguage: [String: String]] {
        var result: [SupportedLanguage: [String: String]] = [:]
        for language in SupportedLanguage.allCases {
            guard let url = Bundle.main.url(forResource: "Localizable",
                                            withExtension: "strings",
                                            subdirectory: nil,
                                            localization: language.rawValue),
                  let table = NSDictionary(contentsOf: url) as? [String: String]
            else {
                Logger.loc.warning("Failed to load Localizable.strings for \(language.rawValue, privacy: .public)")
                continue
            }
            result[language] = table
        }
        return result
    }

    // MARK: - String Lookup

    /// Returns the translation for `key` in the currently active language.
    ///
    /// Reading `currentLanguage` establishes an `@Observable` dependency so
    /// that SwiftUI views calling this method are re-evaluated when the
    /// language changes. Unresolved keys fall back to the English table and
    /// finally to the key itself.
    func localizedString(forKey key: String) -> String {
        if let value = translations[currentLanguage]?[key] { return value }
        if let value = translations[.english]?[key] { return value }
        return key
    }
}
