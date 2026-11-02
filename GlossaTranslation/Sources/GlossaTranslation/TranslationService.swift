import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


/// Anything that can translate text. The real one calls the cloud service.
/// The tests use a fake one.
public protocol TranslationService: Sendable {
    /// Translates HTML snippets into `targetLanguage`. The source language is
    /// detected by the service. Returns one result per snippet, in the same order.
    func translateHTML(_ snippets: [String], to targetLanguage: String) async throws -> [String]
}

/// Uses Google Cloud Translation (Basic, v2) over HTTPS (FR11, NFR3).
public struct GoogleTranslationService: TranslationService {
    public static let endpoint = URL(string: "https://translation.googleapis.com/language/translate/v2")!

    private let apiKey: String
    private let session: URLSession

    /// `timeout` is how many seconds we wait for an answer. FR11 says 5.
    public init(apiKey: String, timeout: TimeInterval = 5, session: URLSession? = nil) {
        self.apiKey = apiKey
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout
            self.session = URLSession(configuration: config)
        }
    }

    public func translateHTML(_ snippets: [String], to targetLanguage: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw TranslationError.invalidAPIKey }
        guard !snippets.isEmpty else { return [] }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The key goes in a header, not in the URL, so it does not end up in logs (NFR3).
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        // No "source" field, so the service detects the source language itself.
        request.httpBody = try JSONEncoder().encode(
            RequestBody(q: snippets, target: targetLanguage, format: "html")
        )

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw TranslationError.timeout
        } catch {
            throw TranslationError.network(error.localizedDescription)
        }
        let (data, response) = result

        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw TranslationError.invalidAPIKey
            }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message ?? "Unknown error"
            if message.contains("API key") {
                throw TranslationError.invalidAPIKey
            }
            throw TranslationError.service(statusCode: http.statusCode, message: message)
        }

        guard let body = try? JSONDecoder().decode(ResponseBody.self, from: data),
              body.data.translations.count == snippets.count else {
            throw TranslationError.invalidResponse
        }
        return body.data.translations.map { $0.translatedText }
    }

    private struct RequestBody: Encodable {
        let q: [String]
        let target: String
        let format: String
    }

    private struct ResponseBody: Decodable {
        struct Inner: Decodable {
            struct Item: Decodable {
                let translatedText: String
            }
            let translations: [Item]
        }
        let data: Inner
    }

    private struct ErrorBody: Decodable {
        struct Inner: Decodable {
            let message: String
        }
        let error: Inner
    }
}
