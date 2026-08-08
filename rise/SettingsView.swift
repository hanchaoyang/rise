import SwiftUI
import OSLog

// MARK: - Settings View

/// Settings window that allows the user to enter and save their Twelve Data API key.
///
/// The key is persisted via `@AppStorage` and used by `PriceService` for all
/// price requests. After saving, an immediate fetch is triggered so the menu
/// bar reflects the latest data without waiting for the timer.
struct SettingsView: View {

    // MARK: - State

    /// Persisted API key synced with UserDefaults via `@AppStorage`.
    @AppStorage(Constants.apiKeyStorageKey) private var storedKey = ""

    /// Local copy of the key for editing in the text field.
    @State private var apiKey = ""

    /// Tracks whether the key has been saved during this session.
    @State private var isSaved = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section: API key input
            Text("Twelve Data API Key")
                .font(.headline)

            TextField("Enter API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            HStack(spacing: 10) {
                // Save button — persists key + triggers immediate fetch
                Button("Save") {
                    storedKey = apiKey
                    isSaved = true
                    Logger.price.info("API key saved — triggering fetch")
                    Task { await PriceService.shared.fetchPrice() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)

                // Feedback label shown after a successful save
                if isSaved {
                    Text("Saved")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            // Section: registration hint
            Text("Register at twelvedata.com for a free API Key")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: Constants.settingsWindowWidth, minHeight: Constants.settingsWindowHeight)
        .onAppear {
            apiKey = storedKey
        }
    }
}
