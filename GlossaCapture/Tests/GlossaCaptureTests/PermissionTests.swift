import Testing
@testable import GlossaCapture

// FR6: Request Screen Recording Permission

@Test func grantedPermissionAllowsStartWithoutAsking() {
    let permission = FakePermission(status: .granted)
    let gate = PermissionGate(permission: permission)

    #expect(gate.checkBeforeStart() == .granted)
    #expect(permission.requestCount == 0)
}

@Test func missingPermissionIsRequestedFromTheSystem() {
    let permission = FakePermission(status: .notGranted, grantOnRequest: true)
    let gate = PermissionGate(permission: permission)

    #expect(gate.checkBeforeStart() == .granted)
    #expect(permission.requestCount == 1)
}

@Test func deniedPermissionShowsExplanation() {
    let permission = FakePermission(status: .notGranted)
    let gate = PermissionGate(permission: permission)

    #expect(gate.checkBeforeStart() == .needsPermission(explanation: PermissionGate.explanation))
    #expect(PermissionGate.explanation.contains("Screen Recording"))
}

@Test func deniedMessageMatchesRequirement() {
    #expect(PermissionGate.deniedMessage == "Screen recording permission is required")
    #expect(CaptureError.permissionDenied.userMessage == "Screen recording permission is required")
}

@MainActor @Test func settingsButtonOpensSystemSettings() {
    let permission = FakePermission(status: .notGranted)
    let gate = PermissionGate(permission: permission)

    gate.openSystemSettings()

    #expect(permission.settingsOpened == 1)
}

@Test func captureDoesNotStartWithoutPermission() async {
    let capturer = FakeCapturer([.frame(makeFrame())])
    let controller = CaptureController(
        capturer: capturer,
        permission: FakePermission(status: .notGranted)
    )

    #expect(throws: CaptureError.permissionDenied) {
        try await controller.start(source: .display(id: "1")) { _ in }
    }
    #expect(await controller.isRunning == false)
    #expect(await controller.runCycle() == nil)
    #expect(await capturer.captureCount == 0)
}
