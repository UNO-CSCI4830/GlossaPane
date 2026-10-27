import Foundation

#if canImport(Vision) && canImport(CoreGraphics)
import CoreGraphics
import Vision
#endif

/// One line recognized by FR9, including where it belongs on the screen.
public struct RecognizedTextLine: Equatable, Sendable {
    public let text: String
    public let screenRect: ScreenRect

    public init(text: String, screenRect: ScreenRect) {
        self.text = text
        self.screenRect = screenRect
    }
}

/// Result of one FR9 OCR cycle. Empty OCR tells the integration layer to
/// clear existing overlays and not call the translation service.
public struct OCRResult: Equatable, Sendable {
    public let lines: [RecognizedTextLine]

    public init(lines: [RecognizedTextLine]) {
        self.lines = lines
    }

    public var shouldClearOverlays: Bool { lines.isEmpty }
    public var shouldSendForTranslation: Bool { !lines.isEmpty }
}

public enum OCRError: Error, Equatable, Sendable {
    case imageCreationFailed
    case recognitionFailed(String)
    case unsupportedPlatform
}

/// Pure coordinate conversion used by OCR and unit tests.
/// Vision rectangles use a bottom-left normalized origin; GlossaPane screen
/// rectangles use a top-left origin, so Y must be flipped.
public enum OCRGeometry {
    public static func screenRect(
        normalizedX: Double,
        normalizedY: Double,
        normalizedWidth: Double,
        normalizedHeight: Double,
        in frame: CapturedFrame
    ) -> ScreenRect {
        let x = frame.screenFrame.x + normalizedX * frame.screenFrame.width
        let y = frame.screenFrame.y
            + (1.0 - normalizedY - normalizedHeight) * frame.screenFrame.height
        let width = normalizedWidth * frame.screenFrame.width
        let height = normalizedHeight * frame.screenFrame.height

        return ScreenRect(x: x, y: y, width: width, height: height)
    }
}

/// FR9: Recognize Text With OCR.
///
/// On macOS this uses Apple's Vision framework. It returns each line's text and
/// its screen position/size. An image with no text returns an empty array; the
/// integration layer can use that to clear overlays and skip translation, as
/// required by FR9.
public struct OCRService: Sendable {
    public init() {}

    public func recognize(in frame: CapturedFrame) async throws -> OCRResult {
        OCRResult(lines: try await recognizeText(in: frame))
    }

    public func recognizeText(in frame: CapturedFrame) async throws -> [RecognizedTextLine] {
        #if canImport(Vision) && canImport(CoreGraphics)
        guard let image = frame.makeCGImage() else {
            throw OCRError.imageCreationFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }

        let observations = request.results ?? []
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            let box = observation.boundingBox
            return RecognizedTextLine(
                text: text,
                screenRect: OCRGeometry.screenRect(
                    normalizedX: Double(box.origin.x),
                    normalizedY: Double(box.origin.y),
                    normalizedWidth: Double(box.size.width),
                    normalizedHeight: Double(box.size.height),
                    in: frame
                )
            )
        }
        #else
        throw OCRError.unsupportedPlatform
        #endif
    }
}
