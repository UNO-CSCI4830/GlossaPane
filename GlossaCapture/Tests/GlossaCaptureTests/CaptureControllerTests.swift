import Testing
@testable import GlossaCapture

// FR7: Capture Selected Source (plus FR8 inside the capture cycle)

private func makeController(_ steps: [FakeCapturer.Step]) -> (CaptureController, FakeCapturer) {
    let capturer = FakeCapturer(steps)
    let controller = CaptureController(capturer: capturer, permission: FakePermission(status: .granted))
    return (controller, capturer)
}

@Test func invalidSourceDoesNotStart() async {
    let (controller, capturer) = makeController([.frame(makeFrame())])

    #expect(throws: CaptureError.invalidSource) {
        try await controller.start(source: .region(x: 0, y: 0, width: 0, height: 10)) { _ in }
    }
    #expect(await controller.isRunning == false)
    #expect(await capturer.captureCount == 0)
}

@Test func firstCaptureIsSentToOCR() async throws {
    let frame = makeFrame()
    let (controller, _) = makeController([.frame(frame)])
    try await controller.begin(source: .display(id: "1"))

    #expect(await controller.runCycle() == .changed(frame))
}

@Test func unchangedCaptureIsSkipped() async throws {
    let (controller, _) = makeController([.frame(makeFrame()), .frame(makeFrame(changedPixels: 1))])
    try await controller.begin(source: .display(id: "1"))

    _ = await controller.runCycle()
    #expect(await controller.runCycle() == .unchanged)
}

@Test func failedCaptureIsRetriedOnNextCycle() async throws {
    let frame = makeFrame()
    let (controller, capturer) = makeController([.fail, .frame(frame)])
    try await controller.begin(source: .display(id: "1"))

    #expect(await controller.runCycle() == .captureFailed(consecutiveFailures: 1))
    #expect(await controller.isRunning)
    #expect(await controller.runCycle() == .changed(frame))
    #expect(await capturer.captureCount == 2)
}

@Test func threeFailuresInARowStopCapture() async throws {
    let (controller, _) = makeController([.fail])
    try await controller.begin(source: .display(id: "1"))

    #expect(await controller.runCycle() == .captureFailed(consecutiveFailures: 1))
    #expect(await controller.runCycle() == .captureFailed(consecutiveFailures: 2))
    #expect(await controller.runCycle() == .stopped(message: "Screen capture failed"))
    #expect(await controller.isRunning == false)
    #expect(await controller.runCycle() == nil)
}

@Test func successResetsTheFailureCount() async throws {
    let (controller, _) = makeController([.fail, .fail, .frame(makeFrame()), .fail, .fail, .frame(makeFrame())])
    try await controller.begin(source: .display(id: "1"))

    for _ in 0..<6 {
        _ = await controller.runCycle()
    }
    #expect(await controller.isRunning)
}

@Test func stopEndsCapture() async throws {
    let (controller, capturer) = makeController([.frame(makeFrame())])
    try await controller.begin(source: .display(id: "1"))
    _ = await controller.runCycle()

    await controller.stop()

    #expect(await controller.isRunning == false)
    #expect(await controller.runCycle() == nil)
    #expect(await capturer.captureCount == 1)
}

@Test func restartingProcessesTheFirstFrameAgain() async throws {
    let frame = makeFrame()
    let (controller, _) = makeController([.frame(frame)])
    try await controller.begin(source: .display(id: "1"))
    _ = await controller.runCycle()

    await controller.stop()
    try await controller.begin(source: .display(id: "1"))

    #expect(await controller.runCycle() == .changed(frame))
}

@Test(.timeLimit(.minutes(1)))
func runningLoopReportsEventsAndStopsAfterThreeFailures() async throws {
    let capturer = FakeCapturer([.frame(makeFrame()), .fail])
    let controller = CaptureController(
        capturer: capturer,
        permission: FakePermission(status: .granted),
        interval: .milliseconds(10)
    )
    let (events, continuation) = AsyncStream<CaptureEvent>.makeStream()

    try await controller.start(source: .display(id: "1")) { event in
        continuation.yield(event)
        if case .stopped = event { continuation.finish() }
    }

    var received: [CaptureEvent] = []
    for await event in events {
        received.append(event)
    }

    #expect(received.count == 4)
    if case .changed = received.first {} else {
        Issue.record("first event should be .changed, got \(String(describing: received.first))")
    }
    #expect(Array(received.dropFirst()) == [
        .captureFailed(consecutiveFailures: 1),
        .captureFailed(consecutiveFailures: 2),
        .stopped(message: "Screen capture failed"),
    ])
    #expect(await controller.isRunning == false)
}
