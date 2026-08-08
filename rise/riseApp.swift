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
            Text("Gold $\(PriceService.shared.displayPrice)")
        }

        // MARK: - Settings

        Settings {
            SettingsView()
        }
        .defaultSize(width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight)
    }
}

// MARK: - Menu Content

/// Dropdown menu shown when the user clicks the menu bar item.
fileprivate struct MenuContentView: View {
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
