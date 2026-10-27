import Testing
@testable import GlossaCapture

// FR8: Detect Screen Changes (frames are 100 pixels, so 1 pixel = 1 percent)

@Test func firstFrameIsAlwaysProcessed() {
    var detector = ChangeDetector()

    #expect(detector.evaluate(makeFrame()) == .process(changedFraction: 1))
}

@Test func identicalFrameIsSkipped() {
    var detector = ChangeDetector()
    _ = detector.evaluate(makeFrame())

    #expect(detector.evaluate(makeFrame()) == .skip(changedFraction: 0))
}

@Test func onePercentChangeIsSkipped() {
    var detector = ChangeDetector()
    _ = detector.evaluate(makeFrame())

    #expect(detector.evaluate(makeFrame(changedPixels: 1)) == .skip(changedFraction: 0.01))
}

@Test func exactlyTwoPercentChangeIsProcessed() {
    var detector = ChangeDetector()
    _ = detector.evaluate(makeFrame())

    #expect(detector.evaluate(makeFrame(changedPixels: 2)) == .process(changedFraction: 0.02))
}

@Test func largeChangeIsProcessed() {
    var detector = ChangeDetector()
    _ = detector.evaluate(makeFrame())

    #expect(detector.evaluate(makeFrame(changedPixels: 50)) == .process(changedFraction: 0.5))
}

@Test func sizeChangeIsProcessed() {
    var detector = ChangeDetector()
    _ = detector.evaluate(makeFrame())

    #expect(detector.evaluate(makeFrame(width: 20, height: 10)) == .process(changedFraction: 1))
}

@Test func comparesWithLastProcessedFrameNotLastCapturedFrame() {
    var detector = ChangeDetector()
    _ = detector.evaluate(makeFrame(changedPixels: 0))   // processed

    // 1 percent each time is skipped, but it adds up against the processed frame.
    #expect(detector.evaluate(makeFrame(changedPixels: 1)) == .skip(changedFraction: 0.01))
    #expect(detector.evaluate(makeFrame(changedPixels: 2)) == .process(changedFraction: 0.02))
    // The 2 percent frame is now the reference.
    #expect(detector.evaluate(makeFrame(changedPixels: 2)) == .skip(changedFraction: 0))
}

@Test func resetForgetsTheLastFrame() {
    var detector = ChangeDetector()
    _ = detector.evaluate(makeFrame())
    detector.reset()

    #expect(detector.evaluate(makeFrame()) == .process(changedFraction: 1))
}
