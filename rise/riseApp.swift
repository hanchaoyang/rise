import SwiftUI

/// Entry point of the application.
///
/// Displays the current gold price in the macOS menu bar via ``MenuBarExtra``
/// and provides a settings window for configuring the Twelve Data API key
/// along with an about window.
@main
struct RiseApp: App {
    private let priceService = PriceService.shared

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

        // MARK: - About

        Window("About", id: "about") {
            AboutView()
        }
        .defaultSize(width: Constants.aboutWindowWidth, height: Constants.aboutWindowHeight)
    }

    // MARK: - Price Label

    /// Human-readable menu bar label derived from the current price status.
    private var priceLabel: String {
        switch priceService.status {
        case .initial:     return "Gold  ---"
        case .noKey:       return "Gold  No API Key"
        case .unauthorized:return "Gold  Invalid Key"
        case .rateLimited: return "Gold  Rate Limited"
        case .value(let v):
            let formatted = v.formatted(
                .number.precision(.fractionLength(2)).grouping(.never)
            )
            return "Gold  $\(formatted)"
        case .error:       return "Gold  Fetch Failed"
        }
    }
}
