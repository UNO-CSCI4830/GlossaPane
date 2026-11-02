import Foundation
import GlossaTranslation
import GlossaCapture

/// FR10: Prepares recognized OCR text for translation.
///
/// This component will convert OCR output into the
/// format expected by GlossaTranslation.
///
/// It provides part of the integration needed for FR20.
public enum OCRTranslationAdapter {

    /// Converts one OCR line int a translation item.
    public static func convert(_ line: RecognizedTextLine) -> RecognizedItem {
        
        let rect = line.screenRect

        let boundingBox = CGRect(
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height
        )


        return RecognizedItem(
            text: line.text,
            boundingBox: boundingBox
        )

    }

    /// Converts an OCR result into a translation request. 
    /// 
    /// Returns nil when OCR did not recognize any text.
    public static func makeRequest(from result: OCRResult, targetLanguage: String) -> TranslationRequest? {
        
        guard result.shouldSendForTranslation else {
            return nil
        }

        let items = result.lines.map { line in 
            convert(line)
        }
        
        return TranslationRequest(
            items: items,
            targetLanguage: targetLanguage
        )
    }
    
}