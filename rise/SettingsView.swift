import SwiftUI
import OSLog

// MARK: - Settings View

/// Settings window that allows the user to enter and save their Twelve Data API key.
///
/// The key is persisted via `UserDefaults` and used by `PriceService` for all
/// price requests. After saving, an immediate fetch is triggered so the menu
/// bar reflects the latest data without waiting for the timer.
struct SettingsView: View {

    // MARK: - State

    /// Local copy of the key for editing in the text field, initialized from
    /// persistent storage.
    @State private var apiKey = UserDefaults.standard.string(forKey: Constants.apiKeyStorageKey) ?? ""

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
                .frame(maxWidth: .infinity)
                .onChange(of: apiKey) { _, _ in
                    isSaved = false
                }

            HStack(spacing: 10) {
                // Save button — persists key + triggers immediate fetch
                Button("Save") {
                    PriceService.shared.updateAPIKey(apiKey)
                    isSaved = true
                    Logger.price.info("API key saved — triggering fetch")
                    Task {
                        await PriceService.shared.startPollingIfNeeded()
                        await PriceService.shared.fetchPrice()
                    }
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
    }
}
