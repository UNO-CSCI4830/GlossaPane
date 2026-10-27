import Foundation
import Testing
@testable import GlossaCapture

private actor CallRecorder {
    var startedSource: CaptureSource?
    var stopCount = 0
    var overlayClearCount = 0

    func recordStart(_ source: CaptureSource) {
        startedSource = source
    }

    func recordStop() {
        stopCount += 1
    }

    func recordOverlayClear() {
        overlayClearCount += 1
    }
}

@Test("FR1 refuses to start when no source is selected")
func fr1RequiresSource() async {
    let recorder = CallRecorder()
    let control = TranslationControl(
        startCapture: { source, _ in
            await recorder.recordStart(source)
        },
        stopCapture: {
            await recorder.recordStop()
        }
    )

    do {
        try await control.start { _ in }
        Issue.record("Start should fail without a selected source")
    } catch let error as TranslationControl.ControlError {
        #expect(error == .noSourceSelected)
        #expect(error.userMessage == "Please select a source first")
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(await recorder.startedSource == nil)
    #expect(await control.state == .stopped)
}

@Test("FR1 starts selected source and stop clears overlay")
func fr1StartsAndStops() async throws {
    let recorder = CallRecorder()
    let source = CaptureSource.display(id: "1")

    let control = TranslationControl(
        startCapture: { source, _ in
            await recorder.recordStart(source)
        },
        stopCapture: {
            await recorder.recordStop()
        },
        onStopped: {
            await recorder.recordOverlayClear()
        }
    )

    await control.selectSource(source)
    try await control.start { _ in }

    #expect(await recorder.startedSource == source)
    #expect(await control.state == .running)

    await control.stop()

    #expect(await recorder.stopCount == 1)
    #expect(await recorder.overlayClearCount == 1)
    #expect(await control.state == .stopped)
}

@Test("FR9 maps Vision coordinates into screen coordinates")
func fr9CoordinateMapping() {
    let frame = CapturedFrame(
        width: 1000,
        height: 500,
        pixels: Array(repeating: 0, count: 500_000),
        screenFrame: ScreenRect(x: 100, y: 200, width: 500, height: 250),
        scale: 2,
        source: .display(id: "1")
    )

    let rect = OCRGeometry.screenRect(
        normalizedX: 0.10,
        normalizedY: 0.20,
        normalizedWidth: 0.40,
        normalizedHeight: 0.20,
        in: frame
    )

    #expect(rect == ScreenRect(x: 150, y: 350, width: 200, height: 50))
}

@Test("FR9 empty OCR result clears overlays and skips translation")
func fr9EmptyResultBehavior() {
    let result = OCRResult(lines: [])
    #expect(result.shouldClearOverlays)
    #expect(!result.shouldSendForTranslation)
}

@Test("FR19 saves and reloads language and source type")
func fr19PersistsSettings() {
    let suite = "GlossaPaneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = UserSettingsStore(defaults: defaults)
    store.save(targetLanguage: "Portuguese", source: .window(id: "42"))

    #expect(store.load() == UserSettings(
        targetLanguage: "Portuguese",
        lastSourceType: .window
    ))
}

@Test("FR19 uses safe defaults for missing or damaged settings")
func fr19DamagedSettingsFallsBack() {
    let suite = "GlossaPaneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = UserSettingsStore(defaults: defaults)
    #expect(store.load() == .defaults)

    defaults.set(Data("not-json".utf8), forKey: "GlossaPane.UserSettings.v1")
    #expect(store.load() == .defaults)
}
