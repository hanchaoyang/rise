import SwiftUI

// MARK: - Localized Window Title

extension View {

    /// Binds the hosting window's title to the localized string for `key`.
    ///
    /// The window is captured directly from the view hierarchy, so no
    /// identifier or title matching is required. The title is applied when the
    /// view appears and again whenever the language changes.
    func localizedWindowTitle(_ key: String) -> some View {
        modifier(LocalizedWindowTitleModifier(key: key))
    }
}

/// View modifier backing ``View/localizedWindowTitle(_:)``.
private struct LocalizedWindowTitleModifier: ViewModifier {

    /// Localization key used to resolve the window title.
    let key: String

    /// The hosting window, captured from the view hierarchy on appearance.
    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(WindowReader { window in
                self.window = window
                applyTitle()
            })
            .onChange(of: LocalizationManager.shared.currentLanguage) { _, _ in
                applyTitle()
            }
    }

    /// Applies the localized title for `key` to the captured window.
    private func applyTitle() {
        window?.title = LocalizationManager.shared.localizedString(forKey: key)
    }
}

/// Minimal `NSViewRepresentable` that reports the window hosting its view.
private struct WindowReader: NSViewRepresentable {

    /// Invoked whenever the backing view moves to a window.
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowReaderView()
        view.onWindowChange = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowReaderView)?.onWindowChange = onWindow
    }
}

/// Backing view that observes `viewDidMoveToWindow`.
private final class WindowReaderView: NSView {

    /// Callback invoked whenever the view is attached to or removed from a window.
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
