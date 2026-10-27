import Foundation

/// FR8: Detect Screen Changes.
///
/// Compares each new frame with the last frame that was processed. If fewer
/// than 2 percent of the pixels changed, the frame is skipped (no OCR, no
/// translation, keep the current overlays). Otherwise it goes on to OCR.
public struct ChangeDetector: Sendable {
    public static let defaultThreshold = 0.02

    public enum Decision: Equatable, Sendable {
        /// Send the frame to text recognition.
        case process(changedFraction: Double)
        /// Skip the frame and keep the current overlays.
        case skip(changedFraction: Double)
    }

    /// Share of pixels (0 to 1) that must change before a frame is processed.
    public let threshold: Double
    private var lastProcessed: CapturedFrame?

    public init(threshold: Double = ChangeDetector.defaultThreshold) {
        self.threshold = threshold
    }

    /// Decides whether `frame` needs processing. Only processed frames become
    /// the new comparison image, so slow changes still add up to 2 percent.
    public mutating func evaluate(_ frame: CapturedFrame) -> Decision {
        guard let previous = lastProcessed,
              previous.width == frame.width,
              previous.height == frame.height else {
            // First frame, or the size changed: always process.
            lastProcessed = frame
            return .process(changedFraction: 1)
        }

        let fraction = Self.changedFraction(previous.pixels, frame.pixels)
        if fraction >= threshold {
            lastProcessed = frame
            return .process(changedFraction: fraction)
        }
        return .skip(changedFraction: fraction)
    }

    /// Forgets the last processed frame. Called when capture starts or stops,
    /// so no screen image is kept after translation stops (NFR4).
    public mutating func reset() {
        lastProcessed = nil
    }

    /// Share of pixels that differ between two images of the same size.
    public static func changedFraction(_ a: [UInt32], _ b: [UInt32]) -> Double {
        guard a.count == b.count else { return 1 }
        guard !a.isEmpty else { return 0 }
        var changed = 0
        a.withUnsafeBufferPointer { left in
            b.withUnsafeBufferPointer { right in
                for index in 0..<left.count where left[index] != right[index] {
                    changed += 1
                }
            }
        }
        return Double(changed) / Double(a.count)
    }
}
