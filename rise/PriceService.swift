import Foundation
import Observation
import OSLog

// MARK: - Price Service

/// Singleton service responsible for fetching and caching the current gold price.
///
/// Uses the [Twelve Data](https://twelvedata.com) API to retrieve real-time
/// `XAU/USD` quotes. Automatically refreshes every 300 seconds via a repeating
/// timer. Conforms to `Observable` so SwiftUI views react to price changes.
@Observable
final class PriceService {

    /// Shared singleton instance.
    static let shared = PriceService()

    // MARK: - Status

    /// Represents all possible states of the price-fetching lifecycle.
    enum Status {

        /// App just launched, no fetch attempted yet.
        case initial

        /// No API key has been configured in Settings.
        case noKey

        /// A valid price was successfully retrieved.
        case value(Double)

        /// The most recent fetch failed (network error, parse error, etc.).
        case error
    }

    // MARK: - Properties

    /// Current lifecycle status.
    var status: Status = .initial

    /// Whether an asynchronous fetch is currently in progress.
    var isLoading = false

    /// Human-readable price string suitable for direct UI display.
    var displayPrice: String {
        switch status {
        case .initial: return "---"
        case .noKey:   return "No API Key"
        case .value(let v):
            return v.formatted(.number.precision(.fractionLength(2)))
        case .error:   return "Fetch Failed"
        }
    }

    // MARK: - Private Properties

    /// Repeating timer that triggers periodic price refreshes.
    private var timer: Timer?

    /// Unified decodable model covering both success and error responses.
    private struct APIResponse: Codable {
        let price: String?
        let code: Int?
        let message: String?
        let status: String?
    }

    /// The Twelve Data API key stored in UserDefaults.
    private var apiKey: String {
        UserDefaults.standard.string(forKey: Constants.apiKeyStorageKey) ?? ""
    }

    /// Fully constructed request, or `nil` when no API key is set.
    private var request: URLRequest? {
        guard !apiKey.isEmpty else { return nil }
        var components = URLComponents(string: Constants.apiBaseURL)
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: Constants.goldSymbol),
        ]
        guard let url = components?.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("apikey \(apiKey)", forHTTPHeaderField: "Authorization")
        return req
    }

    // MARK: - Initialization

    /// Private initializer enforces the singleton pattern.
    ///
    /// Kicks off an immediate fetch request and starts a repeating timer
    /// that refreshes the price every 300 seconds (5 minutes).
    private init() {
        Logger.price.info("Service initialized — starting initial fetch and \(Constants.refreshInterval)s timer")
        Task { await fetchPrice() }
        timer = Timer.scheduledTimer(withTimeInterval: Constants.refreshInterval, repeats: true) { [weak self] _ in
            Logger.price.info("Timer fired — refreshing price")
            Task { await self?.fetchPrice() }
        }
        timer?.tolerance = Constants.timerTolerance
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public API

    /// Fetches the latest gold price from the Twelve Data API.
    ///
    /// Updates `status` to the appropriate value upon success, failure,
    /// or missing API key. Safe to call from any context — a loading guard
    /// could be added if rate limiting becomes necessary.
    func fetchPrice() async {
        guard !isLoading else { return }
        guard let request = request else {
            Logger.price.info("No API key configured — skipping fetch")
            status = .noKey
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

#if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                Logger.price.debug("API response body: \(body)")
            }
#endif

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                Logger.price.error("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                status = .error
                return
            }

            Logger.price.debug("HTTP status: \(httpResponse.statusCode)")

            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
            if let priceStr = apiResponse.price, let value = Double(priceStr) {
                Logger.price.info("Price fetched successfully: \(value)")
                status = .value(value)
            } else if let code = apiResponse.code, let msg = apiResponse.message {
                Logger.price.error("API error \(code): \(msg)")
                status = .error
            } else {
                Logger.price.error("Unable to parse price from response")
                status = .error
            }
        } catch {
            Logger.price.error("Price fetch failed: \(error.localizedDescription)")
            status = .error
        }
    }
}

// MARK: - Logging

extension Logger {

    /// Logger instance scoped to the price service subsystem.
    static let price = Logger(
        subsystem: "io.github.hanchaoyang.rise",
        category: "PriceService"
    )
}
