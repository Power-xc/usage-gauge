import Foundation

/// Decodes `codexbar usage --format json` output.
///
/// Only the fields the gauge needs are modelled; the rest of the payload is ignored so CodexBar
/// can add fields without breaking us. A provider that failed comes back with its error message
/// instead of failing the whole read.
public enum CodexBarDecoder {
    public static func decode(_ data: Data) throws -> [ProviderUsage] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { try decodeISO8601($0) }
        let entries = try decoder.decode([Entry].self, from: data)
        return ProviderCatalog.sorted(entries.map(\.providerUsage))
    }

    private struct Entry: Decodable {
        let provider: String
        let usage: Usage?
        let error: ProviderError?

        var providerUsage: ProviderUsage {
            ProviderUsage(id: provider,
                          plan: usage?.loginMethod.map(\.capitalized),
                          session: usage?.primary?.window,
                          weekly: usage?.secondary?.window,
                          errorMessage: error?.message,
                          measuredAt: usage?.updatedAt)
        }
    }

    private struct Usage: Decodable {
        let primary: Window?
        let secondary: Window?
        let loginMethod: String?
        let updatedAt: Date?
    }

    private struct Window: Decodable {
        let usedPercent: Double
        let resetsAt: Date?
        let windowMinutes: Int?

        var window: UsageWindow {
            UsageWindow(usedPercent: usedPercent, resetsAt: resetsAt, windowMinutes: windowMinutes)
        }
    }

    private struct ProviderError: Decodable {
        let message: String?
    }

    private static func decodeISO8601(_ decoder: Decoder) throws -> Date {
        let text = try decoder.singleValueContainer().decode(String.self)
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = plain.date(from: text) ?? fractional.date(from: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Not an ISO 8601 date: \(text)"))
        }
        return date
    }
}
