import SwiftUI

/// Entry point of the application.
///
/// Displays the current gold price in the macOS menu bar via ``MenuBarExtra``
/// and provides a settings window for configuring the Twelve Data API key
/// along with an about window.
@main
struct RiseApp: App {
    private let priceService = PriceService.shared
    private let loc = LocalizationManager.shared

    var body: some Scene {
        // MARK: - Menu Bar

        MenuBarExtra {
            MenuContentView()
        } label: {
            Text(verbatim: priceLabel)
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
        let detail: String
        switch priceService.status {
        case .initial:
            detail = "---"
        case .noKey:
            detail = loc.localizedString(forKey: "No API Key")
        case .unauthorized:
            detail = loc.localizedString(forKey: "Invalid Key")
        case .rateLimited:
            detail = loc.localizedString(forKey: "Rate Limited")
        case .value(let v):
            detail = "$" + v.formatted(
                .number.precision(.fractionLength(2)).grouping(.never)
            )
        case .error:
            detail = loc.localizedString(forKey: "Fetch Failed")
        }
        let template = loc.localizedString(forKey: "Gold  %@")
        return String(format: template, detail)
    }
}
