import Foundation

// MARK: - Localization Manager

/// Singleton that manages runtime language switching.
///
/// Loads translations from the String Catalog (``Localizable.xcstrings``)
/// into an in-memory dictionary at startup and resolves lookups from that
/// dictionary at runtime.  This bypasses ``CFBundle`` caching so that
/// language changes take effect immediately without requiring an app restart.
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

    /// Currently active language.  Changing this property persists the
    /// selection to ``UserDefaults`` and triggers ``@Observable`` re-renders.
    var currentLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue,
                                      forKey: Constants.languageStorageKey)
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

        loadTranslations()
    }

    /// Parses ``Localizable.xcstrings`` into the in-memory translation table.
    private func loadTranslations() {
        guard let url = Bundle.main.url(forResource: "Localizable",
                                        withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              let strings = root["strings"] as? [String: Any]
        else {
            translations[.english] = [:]
            return
        }

        for language in SupportedLanguage.allCases {
            var dict: [String: String] = [:]
            for (key, entry) in strings {
                guard let entryDict = entry as? [String: Any],
                      let localizations = entryDict["localizations"]
                        as? [String: Any],
                      let langEntry = localizations[language.rawValue]
                        as? [String: Any],
                      let stringUnit = langEntry["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String
                else { continue }
                dict[key] = value
            }
            translations[language] = dict
        }
    }

    // MARK: - String Lookup

    /// Returns the translation for `key` in the currently active language.
    ///
    /// ``currentLanguage`` is accessed so that ``@Observable`` tracking
    /// re-evaluates callers when the language changes.
    func localizedString(forKey key: String) -> String {
        _ = currentLanguage
        return translations[currentLanguage]?[key]
            ?? translations[.english]?[key]
            ?? key
    }
}
