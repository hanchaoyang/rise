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
    enum Status: Equatable, Sendable {

        /// App just launched, no fetch attempted yet.
        case initial

        /// No API key has been configured in Settings.
        case noKey

        /// The configured API key was rejected by the server (HTTP 401).
        case unauthorized

        /// The API rate limit has been exceeded (HTTP 429).
        case rateLimited

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

    // MARK: - Private Properties

    /// Custom URL session with explicit timeout configuration.
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.requestTimeout
        config.timeoutIntervalForResource = Constants.resourceTimeout
        return URLSession(configuration: config)
    }()

    /// Structured concurrency task that drives the periodic refresh loop.
    private var refreshTask: Task<Void, Never>?

    /// Unified decodable model covering both success and error responses.
    private struct APIResponse: Codable, Sendable {
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
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.refreshInterval))
                guard let self, !self.apiKey.isEmpty else {
                    Logger.price.info("Timer fired — no API key, skipping")
                    continue
                }
                Logger.price.info("Timer fired — refreshing price")
                await self.fetchPrice()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Public API

    /// Fetches the latest gold price from the Twelve Data API.
    ///
    /// Updates `status` to the appropriate value upon success, failure,
    /// or missing API key. Safe to call from any context — a loading guard
    /// could be added if rate limiting becomes necessary.
    @MainActor
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
            let (data, response) = try await urlSession.data(for: request)

            logResponseBody(data)

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.price.error("Invalid response type")
                status = .error
                return
            }

            Logger.price.debug("HTTP status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                Logger.price.error("HTTP 401 — API key invalid or expired")
                status = .unauthorized
                return
            case 429:
                Logger.price.error("HTTP 429 — rate limited")
                status = .rateLimited
                return
            default:
                Logger.price.error("HTTP error: \(httpResponse.statusCode)")
                status = .error
                return
            }

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

    // MARK: - Private Helpers

    /// Logs the raw API response body in debug builds only.
    private func logResponseBody(_ data: Data) {
        #if DEBUG
        if let body = String(data: data, encoding: .utf8) {
            Logger.price.debug("API response body: \(body)")
        }
        #endif
    }
}
