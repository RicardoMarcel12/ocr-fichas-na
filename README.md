# ocr-fichas-na

A macOS command-line tool that reads scanned images of handwritten registration forms ("fichas de inscripción"), extracts their content via OCR, and exports the results to a CSV file.

## Overview

**ocr-fichas-na** processes a directory of scanned form images, uses Apple Vision's text recognition to identify printed labels (keys) and handwritten fill-ins (values), and produces a structured CSV table. It is designed for batch processing of non-standard forms — each form may have a completely different layout and set of fields.

### Key Capabilities

- **OCR Key-Value Extraction** — Detects printed labels and their adjacent handwritten values using spatial analysis of recognized text blocks.
- **Non-Standard Form Support** — Extracts whatever fields are present on each form without requiring a predefined schema. Raw per-form structure is preserved for a later standardization stage.
- **Empty Field Filtering** — Fields with no handwritten value (or values below a confidence threshold) are automatically discarded.
- **Header Detection** — Captures top-of-form metadata (organization name, course title, location) separately from the form body.
- **Parallel Processing** — Uses structured concurrency to process multiple images concurrently, throttled to `min(CPU cores, 8)` tasks.
- **CLI Progress Reporting** — Displays a visual progress bar (0%–100%) during processing and a summary line on completion (e.g., `45/50 files processed`).
- **Unified Error Model** — All errors across the pipeline are captured in a single `error.log` file with consistent structured format.
- **Graceful Degradation** — Individual file failures do not stop the batch; the tool continues processing remaining files and always produces a CSV with successful results.

## Requirements

- **macOS 13+** (Ventura or later)
- **Swift 6** with strict concurrency checking enabled
- Apple Vision framework (system-provided, no additional install)

## Installation

```bash
git clone https://github.com/<your-org>/ocr-fichas-na.git
cd ocr-fichas-na
swift build -c release
```

The compiled binary will be at `.build/release/ocr-fichas-na`.

## Usage

```bash
ocr-fichas-na <input-directory> [--min-confidence <value>]
```

| Argument / Flag | Description | Default |
|---|---|---|
| `<input-directory>` | Path to the directory containing scanned form images (JPEG, PNG, TIFF, HEIC). | *(required)* |
| `--min-confidence` | Minimum OCR confidence threshold (0.0–1.0). Values below this are treated as empty. | `0.25` |

### Example

```bash
ocr-fichas-na ./scanned-forms --min-confidence 0.3
```

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | All files processed successfully. |
| `1` | One or more files failed during processing. The CSV is still produced with successful results. |

## How It Works

### OCR Pipeline

1. **File Discovery** — Scans the input directory for supported image files.
2. **Image Loading** — Reads each image from disk.
3. **OCR Recognition** — Runs Apple Vision `VNRecognizeTextRequest` with `.accurate` recognition level and `es`/`en` language hints.
4. **Spatial Analysis** — Uses bounding-box positions to associate printed labels (keys) with adjacent handwritten text (values). A label is identified as text ending with a colon (`:`), which is stripped from the output key.
5. **Filtering** — Discards fields with empty, whitespace-only, or low-confidence values.
6. **CSV Writing** — Serializes extracted `FormData` objects to a CSV file.

### Data Model

Each processed image produces a **`FormData`** object:

| Field | Type | Description |
|---|---|---|
| `fileName` | `String` | Base name of the source image file. |
| `header` | `[String]` | Recognized header/title lines from the top of the form (may be empty). |
| `fields` | `[FormField]` | Ordered array of key-value pairs, preserving top-to-bottom, left-to-right reading order. |
| `averageConfidence` | `Float` | Mean confidence score across all recognized observations. |

Each **`FormField`** contains:

| Field | Type | Description |
|---|---|---|
| `key` | `String` | Printed label (colon stripped, trimmed). |
| `value` | `String` | Handwritten fill-in (trimmed, newlines sanitized). |
| `confidence` | `Float` | Confidence score for the value recognition. |

## Progress Reporting

- When the output is a TTY, a **progress bar** updates in-place after each file is processed.
- When the output is piped or redirected, the progress bar is suppressed; only the final summary line is printed.
- On completion, a summary line is displayed: `{successful}/{total} files processed`.

## Error Handling

### Unified Error Model

All errors across every pipeline stage are captured in a single `error.log` file located in the input directory. If the input directory is not writable, the tool falls back to the current working directory.

Each error entry follows a bracket-tagged format:

```
[2026-03-10T14:30:00Z] [ERROR] [image-loading] photo.jpg — Could not decode image
```

| Field | Description |
|---|---|
| Timestamp | UTC, ISO 8601 with Z suffix. |
| Severity | `WARNING` (non-critical, processing continues), `ERROR` (file-level failure, processing continues), or `FATAL` (process-level failure, processing stops). |
| Stage | One of: `file-discovery`, `image-loading`, `ocr-recognition`, `csv-writing`, `output-generation`. |
| File | Affected filename, or `N/A` if not file-specific. |
| Description | Human-readable error message. |

### Error Log Behavior

- **Append-only** — New errors are appended; previous runs are never overwritten.
- **Run separators** — Each run that produces errors is prefixed with: `# --- Run started: 2026-03-10T14:30:00Z ---`
- **No errors, no file** — If a run completes without errors, `error.log` is not created or modified.
- **Per-entry flush** — Each entry is flushed to disk immediately, ensuring persistence even on SIGINT or crash.
- **SIGINT handling** — On Ctrl+C, pending error entries are flushed to disk before exit.
- **Fallback** — If `error.log` cannot be written, errors are still reported to stderr with a warning about the log file.

## Project Structure

```
ocr-fichas-na/
├── Package.swift                     # Swift Package Manager manifest (macOS 13+, Swift 6)
├── Sources/
│   └── OcrFichasNa/
│       ├── OcrFichasNa.swift         # CLI entry point (ArgumentParser)
│       ├── ImageScanner.swift        # File discovery and image loading
│       ├── ImageFile.swift           # Image file model
│       └── CSVWriter.swift           # CSV serialization (RFC 4180)
└── specs/                            # Feature specifications
    ├── 001-cli-progress-errors/      # CLI progress bar & error logging
    ├── 002-shared-error-model/       # Unified error model & error.log
    ├── 003-cli-entry-point/          # CLI argument parsing & entry point
    └── 004-ocr-reader/              # OCR key-value extraction engine
```

## Dependencies

| Dependency | Purpose |
|---|---|
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) `1.3+` | CLI argument parsing |
| Apple Vision framework | Text recognition (`VNRecognizeTextRequest`) — system-provided |

No other external dependencies. The project follows a minimal-dependency philosophy.

## Architecture Principles

- **Swift 6 Strict Concurrency** — All types conform to `Sendable`; complete concurrency checking is enabled.
- **Protocol-Oriented Design** — Key components conform to protocols (e.g., `OCRProcessing`) for testability and extensibility.
- **Structured Concurrency** — Parallel image processing via Swift concurrency with hardware-adaptive task throttling.
- **Single-Threaded Error Writes** — Error entries are written serially; no locking required for the sequential pipeline.

## Limitations (POC Scope)

- No image preprocessing (deskewing, rotation correction, contrast enhancement).
- No multi-page form support — each image is treated as a standalone form.
- No form classification or type detection.
- No field standardization or normalization — raw extraction only.
- No special PII handling. **Production use would require** encryption of extracted data, access controls on output files, and compliance with applicable data protection regulations.
- No test targets (POC scope per project constitution).

## License

*(To be determined)*
