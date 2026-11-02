# GlossaIntegration

GlossaIntegration provides integration utilities for the GlossaPane application. It connects data structures used by different modules, allowing recognized screen text to be prepared for translation.

## Purpose

This package supports **FR10: Passing Recognized OCR Text to the Translation Module**.

It converts OCR results from `GlossaCapture` into translation requests compatible with `GlossaTranslation`.

The package handles data conversion only. It does not perform screen capture, OCR recognition, or translation API requests.

## Dependencies

GlossaIntegration depends on two local Swift packages:

- **GlossaCapture:** Provides `OCRResult`, `RecognizedTextLine`, and `ScreenRect`.
- **GlossaTranslation:** Provides `RecognizedItem` and `TranslationRequest`.

## OCRTranslationAdapter

The `OCRTranslationAdapter` provides two static functions.

### `convert(_:)`

Converts a single `RecognizedTextLine` into a `RecognizedItem`.

The conversion preserves the recognized text and screen coordinates while creating the bounding rectangle expected by the translation module.

### `makeRequest(from:targetLanguage:)`

Converts an `OCRResult` into a `TranslationRequest`.

The function:

- Converts recognized text lines into translation items.
- Preserves the original order of recognized lines.
- Preserves screen coordinates.
- Includes the selected target language.
- Returns `nil` when the OCR result contains no lines.

## Testing

The package uses Swift Testing.

The tests verify:

1. Single-line text and coordinate preservation.
2. Empty OCR result handling.
3. Multiple-line conversion and ordering.
4. Target-language preservation.

To run the tests, navigate to the `GlossaIntegration` directory and execute:

```powershell
swift test --jobs 1
```

All four adapter tests have passed on Windows using Swift 6.4.1.

## Integration Notes

GlossaIntegration provides the data conversion needed for FR10.

The complete capture-to-OCR-to-translation workflow is not implemented by this package alone. The application integration work under FR20 must connect the OCR output, adapter, and translation service.

The adapter does not contact Google Cloud Translation directly.

## Platform Compatibility

GlossaPane primarily targets macOS.

Windows testing of this package requires compatible implementations of its dependencies. The translation module currently uses conditional imports and platform-specific handling for Apple Security, CoreGraphics, and FoundationNetworking.

The complete application workflow must still be validated on macOS.