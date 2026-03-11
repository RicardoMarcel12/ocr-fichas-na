# Plan: Refactor CLI to Add Vision OCR with Structured Concurrency

The project currently lists image files into a CSV without OCR. The plan restructures the codebase into three protocol-oriented components (`FileSystemManager`, `OCRProcessor`, `CSVExporter`), integrates Apple's Vision framework for text recognition, processes images in parallel via `async/await`, and outputs a CSV with columns: File Name, Detected Text, Confidence Level.

## Steps

1. **Define protocols and error types** in a new [Errors.swift](Sources/OcrFichasNa/Errors.swift) and update existing files. Create `FileSystemManaging`, `OCRProcessing`, and `CSVExporting` protocols that each component will conform to. Define a unified `AppError` enum (cases: `notADirectory`, `fileSizeUnavailable`, `ocrFailed`, `imageLoadFailed`, `csvWriteFailed`) replacing the current `ScanError`.

2. **Refactor `ImageFile` model** in [ImageFile.swift](Sources/OcrFichasNa/ImageFile.swift). Replace current fields (`directory`, `filename`, `size`, `status`) with OCR-oriented fields: `fileName: String`, `detectedText: String`, `confidence: Float`. Keep it `Sendable`.

3. **Rename and refactor `ImageScanner` → `FileSystemManager`** in [ImageScanner.swift → FileSystemManager.swift](Sources/OcrFichasNa/ImageScanner.swift). Conform to `FileSystemManaging` protocol. Keep the directory-scanning and extension-filtering logic, but return `[URL]` (image file URLs) instead of `[ImageFile]`, since OCR results will be appended later by the processor.

4. **Create `OCRProcessor`** in a new [OCRProcessor.swift](Sources/OcrFichasNa/OCRProcessor.swift). Conform to `OCRProcessing` protocol. Use `VNRecognizeTextRequest` from the Vision framework. Expose an `async` method `func process(imageURLs: [URL]) async throws -> [ImageFile]` that uses a `TaskGroup` to process images in parallel. Each task loads a `CGImage`, runs the text-recognition request, concatenates recognized strings (sanitizing newlines), and averages confidence. Return `ImageFile` results.

5. **Rename and refactor `CSVWriter` → `CSVExporter`** in [CSVWriter.swift → CSVExporter.swift](Sources/OcrFichasNa/CSVWriter.swift). Conform to `CSVExporting` protocol. Update the header to `File Name,Detected Text,Confidence Level` and serialize the new `ImageFile` model fields. Sanitize detected text by replacing `\n` and `\r` with spaces.

6. **Update the entry point** in [OcrFichasNa.swift](Sources/OcrFichasNa/OcrFichasNa.swift). Change `run()` to `mutating func run() async throws` (Swift Argument Parser supports `AsyncParsableCommand`). Wire the three components: `FileSystemManager` → `OCRProcessor` → `CSVExporter`. Print a summary with image count and output path.

## Further Considerations

1. **`AsyncParsableCommand` conformance:** The struct should conform to `AsyncParsableCommand` instead of `ParsableCommand` so that `run() async throws` is valid — verify the swift-argument-parser 1.7 API supports this.
2. **Concurrency throttling:** Should image processing be limited (e.g., max 4–8 concurrent tasks via `TaskGroup`) to avoid memory pressure on large directories? Recommend yes, using a simple semaphore or batching pattern.
3. **macOS deployment target:** Vision's `VNRecognizeTextRequest` with `.accurate` recognition level requires macOS 10.15+; the current target is macOS 13, so this is fine — but the newer `VNRecognizeTextRequest` revision-3 API (macOS 13+) could be used directly for cleaner code.
