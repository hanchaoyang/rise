import SwiftUI

// MARK: - About View

/// About window that displays the app name, version, and a link to the
/// project's GitHub repository.
struct AboutView: View {

    // MARK: - Constants

    private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Rise"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    private let repoURL = URL(string: "https://github.com/hanchaoyang/rise")
    private let loc = LocalizationManager.shared

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
            Text(String(format: loc.localizedString(forKey: "Version %@"), version))
                .font(.footnote)
                .foregroundStyle(.secondary)

            // GitHub link
            if let repoURL {
                Link(destination: repoURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text(verbatim: loc.localizedString(forKey: "GitHub Repository"))
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .localizedWindowTitle("About")
    }
}
