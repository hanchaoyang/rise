import SwiftUI

// MARK: - Menu Content

/// Dropdown menu shown when the user clicks the menu bar item.
struct MenuContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    private let priceService = PriceService.shared
    private let loc = LocalizationManager.shared

    var body: some View {
        // Refresh — fetches the latest price immediately
        Button {
            Task { await priceService.fetchPrice() }
        } label: {
            Text(verbatim: loc.localizedString(forKey: "Refresh"))
        }
        .disabled(priceService.isLoading)

        // Open settings window (brings app to foreground first)
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            Text(verbatim: loc.localizedString(forKey: "Settings"))
        }

        // About this application
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "about" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        } label: {
            Text(verbatim: loc.localizedString(forKey: "About"))
        }

        Divider()

        // Terminate the application completely
        Button {
            NSApp.terminate(nil)
        } label: {
            Text(verbatim: loc.localizedString(forKey: "Quit"))
        }
    }
}
