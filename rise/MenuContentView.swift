import SwiftUI

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
