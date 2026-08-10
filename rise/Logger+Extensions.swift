import OSLog

extension Logger {

    /// Logger instance scoped to the price service subsystem.
    static let price = Logger(
        subsystem: "io.github.hanchaoyang.rise",
        category: "PriceService"
    )

    /// Logger instance scoped to the localization subsystem.
    static let loc = Logger(
        subsystem: "io.github.hanchaoyang.rise",
        category: "Localization"
    )
}
