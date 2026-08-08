import SwiftUI

// MARK: - Menu Content

/// Dropdown menu shown when the user clicks the menu bar item.
struct MenuContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    private let priceService = PriceService.shared

    var body: some View {
        // Refresh — fetches the latest price immediately
        Button("Refresh") {
            Task { await priceService.fetchPrice() }
        }
        .disabled(priceService.isLoading)

        // Open settings window (brings app to foreground first)
        Button("Settings") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }

        // About this application
        Button("About") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
            DispatchQueue.main.async {
                NSApp.windows.first { $0.title == "About" }?.makeKeyAndOrderFront(nil)
            }
        }

        Divider()

        // Terminate the application completely
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
