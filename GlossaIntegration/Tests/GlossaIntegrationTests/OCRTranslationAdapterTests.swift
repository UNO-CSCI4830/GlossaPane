import Foundation
import Testing
import GlossaCapture
import GlossaTranslation
@testable import GlossaIntegration

@Test("Converting an OCR line preserves its text and coordinates")
func convertRecognizedLine() {
    let line = RecognizedTextLine(
        text: "こんにちは",
        screenRect: ScreenRect(
            x: 100,
            y: 200,
            width: 150,
            height: 30
        )
    )

    let item = OCRTranslationAdapter.convert(line)

    #expect(item.text == "こんにちは")
    #expect(item.boundingBox.origin.x == 100)
    #expect(item.boundingBox.origin.y == 200)
    #expect(item.boundingBox.width == 150)
    #expect(item.boundingBox.height == 30)
}

@Test("Empty OCR results do not create translation requests")
func emptyOCRResult() {
    let result = OCRResult(lines: [])

    let request = OCRTranslationAdapter.makeRequest(
        from: result,
        targetLanguage: "en"
    )

    #expect(request == nil)
}


@Test("Multiple OCR lines are converted in the correct order")
func multipleOCRLines() {
    let firstLine = RecognizedTextLine(
        text: "こんにちは",
        screenRect: ScreenRect(
            x: 100,
            y: 200,
            width: 150,
            height: 30
        )
    )

    let secondLine = RecognizedTextLine(
        text: "さようなら",
        screenRect: ScreenRect(
            x: 100,
            y: 250,
            width: 180,
            height: 30
        )
    )

    let result = OCRResult(
        lines: [firstLine, secondLine]
    )

    let request = OCRTranslationAdapter.makeRequest(
        from: result,
        targetLanguage: "en"
    )

    #expect(request?.items.count == 2)
    #expect(request?.items[0].text == "こんにちは")
    #expect(request?.items[1].text == "さようなら")

    #expect(request?.items[0].boundingBox.origin.y == 200)
    #expect(request?.items[1].boundingBox.origin.y == 250)
}


@Test("Translation requests preserve the selected target language")
func targetLanguagePreserved() {
    let line = RecognizedTextLine(
        text: "Hello",
        screenRect: ScreenRect(
            x: 50,
            y: 100,
            width: 120,
            height: 25
        )
    )

    let result = OCRResult(lines: [line])

    let request = OCRTranslationAdapter.makeRequest(
        from: result,
        targetLanguage: "ja"
    )

    #expect(request?.targetLanguage == "ja")
    #expect(request?.items.count == 1)
}

