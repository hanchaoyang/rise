import SwiftUI

// MARK: - About View

/// About window that displays the app name, version, and a link to the
/// project's GitHub repository.
struct AboutView: View {

    // MARK: - Constants

    private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Rise"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    private let repoURL = URL(string: "https://github.com/hanchaoyang/rise")!

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {
            // App icon
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.bottom, 4)

            // App name
            Text(appName)
                .font(.title.weight(.semibold))

            // Version
            Text("Version \(version)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // GitHub link
            Button {
                NSWorkspace.shared.open(repoURL)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                    Text("GitHub Repository")
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pointingHand.pop()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
