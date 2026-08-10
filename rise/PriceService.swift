import Foundation
import Observation
import OSLog

// MARK: - Price Service

/// Singleton service responsible for fetching and caching the current gold price.
///
/// Uses the [Twelve Data](https://twelvedata.com) API to retrieve real-time
/// `XAU/USD` quotes. Automatically refreshes every 300 seconds via a repeating
/// timer. Conforms to `Observable` so SwiftUI views react to price changes.
@MainActor @Observable
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
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    /// Structured concurrency task that drives the periodic refresh loop.
    private var refreshTask: Task<Void, Never>?

    /// Unified decodable model covering both success and error responses.
    private static let jsonDecoder = JSONDecoder()

    private struct APIResponse: Decodable, Sendable {
        let price: String?
        let code: Int?
        let message: String?
    }

    /// The Twelve Data API key persisted in UserDefaults.
    private var apiKey: String = ""

    /// The current URLRequest, rebuilt automatically when the API key changes.
    private var currentRequest: URLRequest?

    /// Builds a URLRequest for the Twelve Data price endpoint, or `nil` when no key is set.
    private static func buildRequest(for key: String) -> URLRequest? {
        guard !key.isEmpty else { return nil }
        guard var components = URLComponents(string: Constants.apiBaseURL) else {
            Logger.price.error("Failed to create URL components for \(Constants.apiBaseURL, privacy: .public)")
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: Constants.goldSymbol),
        ]
        guard let url = components.url else {
            Logger.price.error("Failed to build URL from components")
            return nil
        }
        var req = URLRequest(url: url)
        req.setValue("apikey \(key)", forHTTPHeaderField: "Authorization")
        return req
    }

    /// Sets the API key and rebuilds the current request.
    /// Property observers do not fire during `init`, so this method ensures the
    /// request is always kept in sync.
    private func setAPIKey(_ key: String) {
        apiKey = key
        currentRequest = PriceService.buildRequest(for: key)
    }

    // MARK: - Initialization

    /// Private initializer enforces the singleton pattern.
    ///
    /// Performs an initial fetch and, once it completes, starts the repeating
    /// timer that refreshes the price on every interval when a key is set.
    private init() {
        let key = UserDefaults.standard.string(forKey: Constants.apiKeyStorageKey) ?? ""
        setAPIKey(key)
        Logger.price.info("Service initialized")
        Task {
            await fetchPrice()
            startPollingIfNeeded()
        }
    }

    // MARK: - Polling

    /// Starts or restarts the polling timer when an API key is available.
    ///
    /// Cancels any previously active timer. If no API key is set the method
    /// is a no-op.
    private func startPollingIfNeeded() {
        refreshTask?.cancel()
        guard !apiKey.isEmpty else { return }
        Logger.price.info("Starting polling with \(Constants.refreshInterval)s interval")
        refreshTask = Task<Void, Never> {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Constants.refreshInterval))
                } catch {
                    break
                }
                Logger.price.info("Timer fired — refreshing price")
                await fetchPrice()
            }
        }
    }

    // MARK: - Public API

    /// Fetches the latest gold price from the Twelve Data API.
    ///
    /// Updates `status` to the appropriate value upon success, failure,
    /// or missing API key. Safe to call from any context — a loading guard
    /// could be added if rate limiting becomes necessary.
    func fetchPrice() async {
        guard !isLoading else { return }
        guard let request = currentRequest else {
            Logger.price.info("No API key configured — skipping fetch")
            status = .noKey
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await urlSession.data(for: request)

#if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                Logger.price.debug("API response body: \(body)")
            }
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.price.error("Invalid response type")
                status = .error
                return
            }

            Logger.price.debug("HTTP status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
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

            let apiResponse = try Self.jsonDecoder.decode(APIResponse.self, from: data)
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

    // MARK: - Key Management

    func updateAPIKey(_ newKey: String, fetchImmediately: Bool = true) {
        setAPIKey(newKey)
        UserDefaults.standard.set(newKey, forKey: Constants.apiKeyStorageKey)
        startPollingIfNeeded()
        if fetchImmediately {
            Task { await fetchPrice() }
        }
    }}
