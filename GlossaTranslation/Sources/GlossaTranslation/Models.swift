import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// One line of text found on the screen. This is what the capture and OCR step
/// hands to the translation step (FR10).
public struct RecognizedItem: Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let boundingBox: CGRect

    public init(id: UUID = UUID(), text: String, boundingBox: CGRect) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
    }
}

/// A batch of lines to translate into one target language, like "en" or "es".
public struct TranslationRequest: Equatable, Sendable {
    public let items: [RecognizedItem]
    public let targetLanguage: String

    public init(items: [RecognizedItem], targetLanguage: String) {
        self.items = items
        self.targetLanguage = targetLanguage
    }
}

/// The translated line. It keeps the same id and position as the original (FR13),
/// so the overlay can put it in the right place.
public struct TranslatedItem: Equatable, Sendable {
    public let id: UUID
    public let originalText: String
    public let translatedText: String
    public let boundingBox: CGRect

    public init(id: UUID, originalText: String, translatedText: String, boundingBox: CGRect) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.boundingBox = boundingBox
    }
}

/// What comes back from one translate call.
/// `rejected` holds the ids of lines that had no text (FR10).
public struct TranslationOutcome: Equatable, Sendable {
    public let results: [TranslatedItem]
    public let rejected: [UUID]

    public init(results: [TranslatedItem], rejected: [UUID]) {
        self.results = results
        self.rejected = rejected
    }
}

public enum TranslationError: Error, Equatable {
    case timeout
    case network(String)
    case invalidAPIKey
    case service(statusCode: Int, message: String)
    case invalidResponse

    /// Short message the main window can show to the user (FR14, NFR3).
    public var userMessage: String {
        switch self {
        case .invalidAPIKey:
            return "Translation service key is missing or invalid"
        case .timeout, .network, .service, .invalidResponse:
            return "Translation unavailable"
        }
    }
}
