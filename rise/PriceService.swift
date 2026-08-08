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

    /// Minimal decodable model matching the Twelve Data price endpoint response.
    private struct PriceResponse: Codable {
        let price: String
    }

    /// Captures API-level errors returned by Twelve Data (e.g. invalid key).
    private struct APIErrorResponse: Codable {
        let code: Int
        let message: String
        let status: String
    }

    /// The Twelve Data API key stored in UserDefaults.
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? ""
    }

    /// Fully constructed request URL, or `nil` when no API key is set.
    private var requestURL: URL? {
        guard !apiKey.isEmpty else { return nil }
        var components = URLComponents(string: "https://api.twelvedata.com/price")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: "XAU/USD"),
            URLQueryItem(name: "apikey", value: apiKey),
        ]
        return components?.url
    }

    // MARK: - Initialization

    /// Private initializer enforces the singleton pattern.
    ///
    /// Kicks off an immediate fetch request and starts a repeating timer
    /// that refreshes the price every 300 seconds (5 minutes).
    private init() {
        Logger.price.info("Service initialized — starting initial fetch and 300s timer")
        Task { await fetchPrice() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Logger.price.info("Timer fired — refreshing price")
            Task { await self?.fetchPrice() }
        }
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
        guard let url = requestURL else {
            Logger.price.info("No API key configured — skipping fetch")
            status = .noKey
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Always log the raw response body for debugging
            if let body = String(data: data, encoding: .utf8) {
                Logger.price.debug("API response body: \(body)")
            }

            let httpResponse = response as? HTTPURLResponse
            Logger.price.debug("HTTP status: \(httpResponse?.statusCode ?? -1)")

            // Attempt to decode a successful price response first
            if let priceResponse = try? JSONDecoder().decode(PriceResponse.self, from: data),
               let value = Double(priceResponse.price) {
                Logger.price.info("Price fetched successfully: \(value)")
                status = .value(value)
                return
            }

            // Check for API-level error (e.g. invalid key, rate limit)
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                Logger.price.error("API error \(errorResponse.code): \(errorResponse.message)")
                status = .error
                return
            }

            Logger.price.error("Unable to parse price from response")
            status = .error
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
