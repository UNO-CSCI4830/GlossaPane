import Foundation

/// A rectangle on the screen, in points, with the origin at the top left of
/// the main display (the same coordinates macOS uses for displays and windows).
public struct ScreenRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// One captured image of the selected source (FR7).
///
/// The image lives in memory only and is never written to disk (NFR4).
public struct CapturedFrame: Equatable, Sendable {
    /// Width of the image in pixels.
    public let width: Int
    /// Height of the image in pixels.
    public let height: Int
    /// One 32-bit BGRA value per pixel, row by row, starting at the top left.
    public let pixels: [UInt32]
    /// Where the image is on the screen, in points. OCR uses this to turn a
    /// position in the image into a position on the screen for the overlay.
    public let screenFrame: ScreenRect
    /// Pixels per point (2 on a Retina display).
    public let scale: Double
    public let source: CaptureSource
    public let capturedAt: Date

    public init(
        width: Int,
        height: Int,
        pixels: [UInt32],
        screenFrame: ScreenRect,
        scale: Double,
        source: CaptureSource,
        capturedAt: Date = Date()
    ) {
        precondition(width >= 0 && height >= 0 && pixels.count == width * height,
                     "pixels must hold exactly width * height values")
        self.width = width
        self.height = height
        self.pixels = pixels
        self.screenFrame = screenFrame
        self.scale = scale
        self.source = source
        self.capturedAt = capturedAt
    }
}

#if canImport(CoreGraphics)
import CoreGraphics

extension CapturedFrame {
    /// Makes a CGImage from the frame, for example for Vision OCR (FR9).
    public func makeCGImage() -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                                     | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
#endif
