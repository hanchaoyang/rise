import SwiftUI

/// Entry point of the application.
///
/// Displays the current gold price in the macOS menu bar via ``MenuBarExtra``
/// and provides a settings window for configuring the Twelve Data API key.
@main
struct RiseApp: App {
    var body: some Scene {
        // MARK: - Menu Bar

        MenuBarExtra {
            MenuContentView()
        } label: {
            Text(priceLabel)
        }

        // MARK: - Settings

        Settings {
            SettingsView()
        }
        .defaultSize(width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight)
    }

    // MARK: - Price Label

    /// Human-readable menu bar label derived from the current price status.
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private var priceLabel: String {
        switch PriceService.shared.status {
        case .initial:     return "Gold $---"
        case .noKey:       return "Gold $No API Key"
        case .unauthorized:return "Gold $Invalid Key"
        case .rateLimited: return "Gold $Rate Limited"
        case .value(let v):
            let formatted = v.formatted(
                .number.precision(.fractionLength(2))
                .locale(Self.posixLocale)
            )
            return "Gold $\(formatted)"
        case .error:       return "Gold $Fetch Failed"
        }
    }
}

// MARK: - Menu Content

/// Dropdown menu shown when the user clicks the menu bar item.
struct MenuContentView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Refresh — fetches the latest price immediately
        Button("Refresh") {
            Task { await PriceService.shared.fetchPrice() }
        }
        .disabled(PriceService.shared.isLoading)

        Divider()

        // Open settings window (brings app to foreground first)
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }

        Divider()

        // Terminate the application completely
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
