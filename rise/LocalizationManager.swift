import Foundation

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

    /// Currently active language. Changing this property persists the selection
    /// and updates `AppleLanguages` so that system APIs such as
    /// `Locale.preferredLanguages` stay in sync with the chosen language.
    var currentLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Constants.languageStorageKey)
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        }
    }

    /// All languages offered in the Settings picker.
    let availableLanguages = SupportedLanguage.allCases

    // MARK: - Private

    /// Translation lookup table keyed by language then source key.
    private var translations: [SupportedLanguage: [String: String]] = [:]

    // MARK: - Initialization

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Constants.languageStorageKey),
           let language = SupportedLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            currentLanguage = .english
        }
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        loadTranslations()
    }

    /// Loads the compiled `Localizable.strings` table for every supported
    /// language into the in-memory translation table.
    private func loadTranslations() {
        for language in SupportedLanguage.allCases {
            guard let url = Bundle.main.url(forResource: "Localizable",
                                            withExtension: "strings",
                                            subdirectory: nil,
                                            localization: language.rawValue),
                  let table = NSDictionary(contentsOf: url) as? [String: String]
            else { continue }
            translations[language] = table
        }
    }

    // MARK: - String Lookup

    /// Returns the translation for `key` in the currently active language.
    ///
    /// The `_ = currentLanguage` line establishes an `@Observable` dependency
    /// so that SwiftUI views calling this method are re-evaluated when the
    /// language changes.
    func localizedString(forKey key: String) -> String {
        _ = currentLanguage
        return translations[currentLanguage]?[key]
            ?? translations[.english]?[key]
            ?? key
    }
}
