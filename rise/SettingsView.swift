import SwiftUI
import OSLog

// MARK: - Settings View

/// Settings window that allows the user to enter and save their Twelve Data API
/// key and select the application language.
///
/// The key and language are persisted via `UserDefaults`. The API key is used
/// by `PriceService` for all price requests. After saving, an immediate fetch
/// is triggered so the menu bar reflects the latest data without waiting for
/// the timer. Language changes take effect immediately after saving.
struct SettingsView: View {

    // MARK: - State

    /// Local copy of the key for editing in the text field, initialized from
    /// persistent storage.
    @State private var apiKey = UserDefaults.standard.string(forKey: Constants.apiKeyStorageKey) ?? ""

    /// Tracks whether the key has been saved during this session.
    @State private var isSaved = false

    /// Language selected in the picker. Initialized from the current language
    /// and applied only when the user taps Save.
    @State private var selectedLanguage = LocalizationManager.shared.currentLanguage

    private let loc = LocalizationManager.shared

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section: API key input
            Text(verbatim: loc.localizedString(forKey: "Twelve Data API Key"))
                .font(.headline)

            TextField(loc.localizedString(forKey: "Enter API Key"), text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .onChange(of: apiKey) { _, _ in
                    isSaved = false
                }

            // Section: Language selector
            Text(verbatim: loc.localizedString(forKey: "Language"))
                .font(.headline)

            Picker(selection: $selectedLanguage) {
                ForEach(loc.availableLanguages) { language in
                    Text(language.displayName).tag(language)
                }
            } label: {
                Text(verbatim: loc.localizedString(forKey: "Language"))
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                // Save button — persists key and language, triggers immediate fetch
                Button {
                    PriceService.shared.updateAPIKey(apiKey)
                    isSaved = true
                    if selectedLanguage != loc.currentLanguage {
                        loc.currentLanguage = selectedLanguage
                    }
                    Logger.price.info("API key saved — triggering fetch")
                } label: {
                    Text(verbatim: loc.localizedString(forKey: "Save"))
                }
                .buttonStyle(.borderedProminent)

                // Feedback label shown after a successful save
                if isSaved {
                    Text(verbatim: loc.localizedString(forKey: "Saved"))
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            // Section: registration hint
            Text(verbatim: loc.localizedString(forKey: "Register at twelvedata.com for a free API Key"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .localizedWindowTitle("Settings")
    }
}
