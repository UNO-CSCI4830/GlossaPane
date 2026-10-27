#if os(macOS) && canImport(ScreenCaptureKit)
import Foundation
import CoreGraphics
@preconcurrency import CoreMedia
import CoreVideo
@preconcurrency import ScreenCaptureKit

/// FR7: Captures the selected display, window, or region with ScreenCaptureKit.
///
/// Source ids:
/// - `.display(id:)` is the CGDirectDisplayID as a decimal string, for example "1".
/// - `.window(id:)` is the CGWindowID as a decimal string, for example "4521".
/// - `.region(...)` is in screen points, with the origin at the top left of the main display.
///
/// GlossaPane's own windows (the translation overlays) are left out of display
/// and region captures, so OCR never reads our own translations back.
public struct SystemScreenCapturer: ScreenCapturer {
    public init() {}

    public func capture(_ source: CaptureSource) async throws -> CapturedFrame {
        guard source.isValid else { throw CaptureError.invalidSource }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.failed(error.localizedDescription)
        }

        let target = try Self.resolve(source, in: content)

        let configuration = SCStreamConfiguration()
        configuration.width = target.pixelWidth
        configuration.height = target.pixelHeight
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        if let sourceRect = target.sourceRect {
            configuration.sourceRect = sourceRect
        }

        let image: RawImage
        do {
            if #available(macOS 14.0, *) {
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: target.filter,
                    configuration: configuration
                )
                guard let raw = RawImage(cgImage: cgImage) else {
                    throw CaptureError.failed("Could not read the captured image")
                }
                image = raw
            } else {
                // macOS 13 has no screenshot API, so grab one frame from a stream.
                image = try await SingleFrameGrabber.grab(
                    filter: target.filter,
                    configuration: configuration
                )
            }
        } catch let error as CaptureError {
            throw error
        } catch {
            throw CaptureError.failed(error.localizedDescription)
        }

        return CapturedFrame(
            width: image.width,
            height: image.height,
            pixels: image.pixels,
            screenFrame: target.screenFrame,
            scale: target.scale,
            source: source
        )
    }

    // MARK: - Finding the source

    private struct Target {
        let filter: SCContentFilter
        let sourceRect: CGRect?
        let screenFrame: ScreenRect
        let scale: Double
        let pixelWidth: Int
        let pixelHeight: Int

        init(filter: SCContentFilter, sourceRect: CGRect?, frame: CGRect, scale: Double) {
            self.filter = filter
            self.sourceRect = sourceRect
            self.screenFrame = ScreenRect(
                x: Double(frame.minX), y: Double(frame.minY),
                width: Double(frame.width), height: Double(frame.height)
            )
            self.scale = scale
            self.pixelWidth = max(1, Int((Double(frame.width) * scale).rounded()))
            self.pixelHeight = max(1, Int((Double(frame.height) * scale).rounded()))
        }
    }

    private static func resolve(_ source: CaptureSource, in content: SCShareableContent) throws -> Target {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == ownPID }

        switch source {
        case .display(let id):
            guard let displayID = CGDirectDisplayID(id),
                  let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureError.sourceNotFound("display \(id)")
            }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            return Target(filter: filter, sourceRect: nil, frame: display.frame,
                          scale: scaleFactor(for: displayID))

        case .window(let id):
            guard let windowID = CGWindowID(id),
                  let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw CaptureError.sourceNotFound("window \(id)")
            }
            let frame = window.frame
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let display = content.displays.first(where: { $0.frame.contains(center) })
            let scale = display.map { scaleFactor(for: $0.displayID) } ?? 1
            let filter = SCContentFilter(desktopIndependentWindow: window)
            return Target(filter: filter, sourceRect: nil, frame: frame, scale: scale)

        case .region(let x, let y, let width, let height):
            let region = CGRect(x: x, y: y, width: width, height: height)
            let center = CGPoint(x: region.midX, y: region.midY)
            guard let display = content.displays.first(where: { $0.frame.contains(center) }) else {
                throw CaptureError.sourceNotFound("region")
            }
            // ScreenCaptureKit wants the region relative to its display.
            let displayFrame = display.frame
            let local = region
                .offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)
                .intersection(CGRect(origin: .zero, size: displayFrame.size))
            guard !local.isNull, local.width >= 1, local.height >= 1 else {
                throw CaptureError.sourceNotFound("region")
            }
            let onScreen = local.offsetBy(dx: displayFrame.minX, dy: displayFrame.minY)
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            return Target(filter: filter, sourceRect: local, frame: onScreen,
                          scale: scaleFactor(for: display.displayID))
        }
    }

    /// Pixels per point for a display (2 on Retina displays).
    private static func scaleFactor(for displayID: CGDirectDisplayID) -> Double {
        guard let mode = CGDisplayCopyDisplayMode(displayID), mode.width > 0 else { return 1 }
        return max(1, Double(mode.pixelWidth) / Double(mode.width))
    }
}

// MARK: - Pixel data

/// Pixels copied out of a CGImage or a CVPixelBuffer in BGRA order.
struct RawImage: Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt32]

    init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt32](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Expects a kCVPixelFormatType_32BGRA buffer.
    init?(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0, bytesPerRow >= width * 4 else { return nil }

        var pixels = [UInt32](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBytes { destination in
            guard let destinationBase = destination.baseAddress else { return }
            for row in 0..<height {
                memcpy(destinationBase + row * width * 4, base + row * bytesPerRow, width * 4)
            }
        }
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

// MARK: - macOS 13 fallback

/// Starts a stream, waits for the first complete frame, and stops the stream.
private final class SingleFrameGrabber: NSObject, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<RawImage, Error>?

    static func grab(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration,
        timeout: TimeInterval = 2
    ) async throws -> RawImage {
        let grabber = SingleFrameGrabber()
        let queue = DispatchQueue(label: "GlossaCapture.SingleFrameGrabber")
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(grabber, type: .screen, sampleHandlerQueue: queue)

        do {
            let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RawImage, Error>) in
                grabber.setContinuation(continuation)
                queue.asyncAfter(deadline: .now() + timeout) {
                    grabber.finish(.failure(CaptureError.failed("Timed out waiting for a frame")))
                }
                stream.startCapture { error in
                    if let error {
                        grabber.finish(.failure(CaptureError.failed(error.localizedDescription)))
                    }
                }
            }
            try? await stream.stopCapture()
            return image
        } catch {
            try? await stream.stopCapture()
            throw error
        }
    }

    private func setContinuation(_ continuation: CheckedContinuation<RawImage, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    /// Resumes the waiting capture once. Later calls do nothing.
    private func finish(_ result: Result<RawImage, Error>) {
        lock.lock()
        let waiting = continuation
        continuation = nil
        lock.unlock()
        waiting?.resume(with: result)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(
                  sampleBuffer, createIfNecessary: false
              ) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[SCStreamFrameInfo.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }
        if let image = RawImage(pixelBuffer: pixelBuffer) {
            finish(.success(image))
        } else {
            finish(.failure(CaptureError.failed("Could not read the captured frame")))
        }
    }
}
#endif
