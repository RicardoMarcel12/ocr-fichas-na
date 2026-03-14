# ocr-fichas-na

A macOS command-line tool that reads scanned images of handwritten registration forms ("fichas de inscripción"), extracts their content via OCR, and exports the results to a CSV file.

## Overview

**ocr-fichas-na** processes a directory of scanned form images, uses Apple Vision's text recognition to identify printed labels (keys) and handwritten fill-ins (values), and produces a structured CSV output. It is designed for batch processing of non-standard registration forms — each form may have a completely different layout and set of fields.

The target documents are **registration forms** ("fichas de inscripción") from organizations like Nueva Acrópolis. A typical form contains a printed header block, labeled fields with handwritten values (e.g., `Nombre:`, `Teléfono:`), checkbox sections, and signature blocks. The tool extracts the raw key-value structure per image and holds it for a later standardization stage.

### Key Capabilities

> **Note:** This project is a work-in-progress POC. Capabilities marked *(planned)* are specified and designed but not yet implemented in `Sources/`.

- **OCR Key-Value Extraction** *(planned)* — Detects printed labels and their adjacent handwritten values using spatial analysis of recognized text blocks.
- **Non-Standard Form Support** *(planned)* — Extracts whatever fields are present on each form without requiring a predefined schema. Raw per-form structure is preserved for a later standardization stage.
- **Empty Field Filtering** *(planned)* — Fields with no handwritten value (or values below a configurable confidence threshold) are automatically discarded.
- **Header Detection** *(planned)* — Captures top-of-form metadata (organization name, course title, location) separately from the form body.
- **Parallel Processing** *(planned)* — Uses structured concurrency to process multiple images concurrently, throttled to `min(CPU cores, 8)` tasks.
- **CLI Progress Reporting** *(planned)* — Displays a visual progress bar (0%–100%) during processing and a summary line on completion (e.g., `45/50 files processed`).
- **Unified Error Model** *(planned)* — All errors across every pipeline stage are captured in a single `error.log` file with consistent structured format and severity classification.
- **Graceful Degradation** *(planned)* — Individual file failures do not stop the batch; the tool continues processing remaining files and always produces a CSV with successful results.
- **Crash-Safe Error Logging** *(planned)* — Error entries are flushed to disk immediately, preserving diagnostics even after SIGINT or unexpected termination.

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

To make it available system-wide, copy or symlink the binary to a directory on your `$PATH`:

```bash
cp .build/release/ocr-fichas-na /usr/local/bin/
```

## Usage

```bash
ocr-fichas-na <directory>
ocr-fichas-na --here
```

The tool accepts exactly one of two mutually exclusive inputs:

| Argument / Flag | Description |
|---|---|
| `<directory>` | Path (absolute or relative) to the directory containing scanned form images. |
| `--here` | Use the current working directory as the scan target. |

Providing both or neither will produce a validation error:

```
Error: Provide either a directory argument or --here, not both.
Error: Provide a directory path or pass --here to scan the current directory.
```

### Additional Flags

| Flag | Type | Default | Description |
|---|---|---|---|
| `--min-confidence` | `Double` | `0.25` | Minimum OCR confidence threshold (0.0–1.0). Key-value pairs with values below this are treated as empty and excluded. |
| `--help` / `-h` | — | — | Display usage instructions, argument descriptions, and flag descriptions. |

### Examples

```bash
# Scan a specific directory
ocr-fichas-na ~/Documents/scanned-forms

# Scan the current directory with a custom confidence threshold
cd ~/Documents/scanned-forms
ocr-fichas-na --here --min-confidence 0.3
```

### Supported Image Formats

JPEG, PNG, TIFF, HEIC — any format supported by the platform's image loading APIs.

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | All files processed successfully. |
| `1` | Application-level error: one or more files failed, or the directory is invalid. The CSV is still produced with successful results when possible. |
| Other | Argument parsing/validation failures (managed by Swift Argument Parser). |

### Output Files

| File | Location | Description |
|---|---|---|
| `output.csv` | Input directory | Pipe-delimited (`|`) CSV with UTF-8+BOM encoding containing extracted form data for all successfully processed files. Uses a union-of-all-keys column strategy; fields are not quoted. |
| `error.log` | Input directory (fallback: CWD) | Created only when errors occur. Append-only log of all pipeline errors. |

## How It Works

### OCR Pipeline

```
┌──────────────────┐    ┌───────────────┐    ┌─────────────────┐
│  File Discovery   │───▶│ Image Loading  │───▶│ OCR Recognition │
│  (find images)    │    │ (read pixels)  │    │ (Vision API)    │
└──────────────────┘    └───────────────┘    └────────┬────────┘
                                                       │
                                                       ▼
┌──────────────────┐    ┌───────────────┐    ┌─────────────────┐
│   CSV Writing     │◀──│   Filtering    │◀──│ Spatial Analysis │
│  (serialize CSV)  │    │ (drop empty)  │    │ (pair key:value)│
└──────────────────┘    └───────────────┘    └─────────────────┘
```

1. **File Discovery** — Scans the input directory for supported image files (case-insensitive extension matching).
2. **Image Loading** — Reads each image from disk. Symlinks are followed.
3. **OCR Recognition** — Runs Apple Vision `VNRecognizeTextRequest` with `.accurate` recognition level and `es` (Spanish) / `en` (English) language hints. For each observation, the recognized string, confidence score, and bounding box are captured.
4. **Spatial Analysis** — Uses bounding-box positions and proximity to associate printed labels (keys) with adjacent handwritten text (values). A label is identified as text ending with a colon (`:`), which is stripped from the output key. Multi-word labels spanning multiple printed lines are captured as a single key.
5. **Filtering** — Discards fields with empty, whitespace-only, or low-confidence values (below `--min-confidence` threshold). All text is sanitized: leading/trailing whitespace trimmed, internal newlines replaced with a single space.
6. **CSV Writing** — Serializes extracted `FormData` objects to a CSV file with RFC 4180 escaping.

### Header Detection

The first 3–5 recognized text blocks (sorted by vertical position, top-to-bottom) that appear above the first detected label (text ending with `:`) are treated as header candidates and stored separately in `FormData.header`. If the first text block is already a label, the header is empty.

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
| `value` | `String` | Handwritten fill-in (trimmed, newlines sanitized to spaces). |
| `confidence` | `Float` | Confidence score for the value recognition. |

### Parallel Processing

Images are processed concurrently using Swift structured concurrency. The maximum number of concurrent tasks is `min(ProcessInfo.processInfo.activeProcessorCount, 8)` — hardware-adaptive and capped at 8 to prevent memory exhaustion. Results are sorted by filename for deterministic output.

## Progress Reporting

- **TTY mode** — When stdout is a terminal, a visual progress bar updates in-place (via `\r` carriage return) after each file is processed, advancing from 0% to 100%.
- **Piped/redirected mode** — The progress bar is suppressed entirely; only the final summary line is printed.
- **Summary line** — On completion: `{successful}/{total} files processed` (e.g., `45/50 files processed`).
- **Empty directories** — Handled gracefully with `0/0 files processed` (no division-by-zero).
- **Large directories** — The progress bar updates efficiently without flooding the terminal (tested for 1,000+ files).

## Error Handling

### Unified Error Model

All errors across every pipeline stage are captured using a single shared error model. No component defines its own incompatible error format.

Every error entry carries five fields and is written to a single `error.log` file:

```
[2026-03-10T14:30:00Z] [ERROR] [image-loading] photo.jpg — Could not decode image
```

| Field | Format | Description |
|---|---|---|
| Timestamp | UTC ISO 8601 with Z suffix | When the error occurred. |
| Severity | `WARNING`, `ERROR`, or `FATAL` | Impact classification (see below). |
| Stage | Pipeline stage identifier | Where in the pipeline the error originated. |
| File | Filename or `N/A` | Which file was affected. |
| Description | Human-readable text | What went wrong and how to act on it. |

### Severity Levels

| Severity | Meaning | Tool Behavior |
|---|---|---|
| `WARNING` | Non-critical issue (e.g., skipped file with unrecognized extension). | Processing continues for all files. Description includes the skip reason. |
| `ERROR` | File-level failure (e.g., OCR fails on a specific image). | Processing continues for remaining files. Description includes the failure reason. |
| `FATAL` | Process-level failure (e.g., output directory not writable). | Processing stops after recording the error. Description starts with `Processing stopped:`. |

### Pipeline Stages

| Stage | Description |
|---|---|
| `file-discovery` | Locating and validating input files in the directory. |
| `image-loading` | Reading image data from disk. |
| `ocr-recognition` | Performing text recognition on an image. |
| `csv-writing` | Serializing results to CSV. |
| `output-generation` | Producing final output artifacts. |

### Error Log Behavior

- **Location** — Primary: the input directory. Fallback: the current working directory (if the input directory is invalid). If neither is writable, errors are reported to stderr only.
- **Append-only** — Previous runs are never overwritten.
- **Run separators** — Each run that produces errors is prefixed with:
  ```
  # --- Run started: 2026-03-10T14:30:00Z ---
  ```
  Written lazily — only when the first error of a run occurs.
- **No errors, no file** — If a run completes without errors, `error.log` is not created or modified.
- **Per-entry flush** — Each entry is flushed to disk immediately after being written, ensuring persistence even on interruption.
- **One line per entry** — Each error occupies exactly one physical line (newlines in descriptions are replaced with spaces), so a partially written entry cannot corrupt previous entries.
- **SIGINT handling** — On Ctrl+C, pending error entries are flushed to `error.log` before exit.
- **Fallback** — If `error.log` cannot be written (permissions, disk full), errors are still reported to stderr with a warning about the log file.

### CLI Error Output

In addition to the log file, every error is printed to **stderr** in real time with the filename and a human-readable description. Each failed file gets its own separate error message.

## Project Structure

```
ocr-fichas-na/
├── Package.swift                     # SPM manifest (macOS 13+, Swift 6)
├── Sources/
│   └── OcrFichasNa/
│       ├── OcrFichasNa.swift         # CLI entry point (AsyncParsableCommand)
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
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) `1.3+` | CLI argument parsing (`AsyncParsableCommand`) |
| Apple Vision framework | Text recognition (`VNRecognizeTextRequest`) — system-provided |

No other external dependencies. The project follows a minimal-dependency philosophy.

## Architecture Principles

- **Swift 6 Strict Concurrency** — All types conform to `Sendable`; complete concurrency checking is enabled. Zero warnings in release builds.
- **Protocol-Oriented Design** — Key components conform to protocols (e.g., `OCRProcessing`: `func process(imageURLs: [URL]) async throws -> [ImageFile]`) for testability and extensibility.
- **Structured Concurrency** — Parallel image processing via Swift concurrency with hardware-adaptive task throttling. OCR work never blocks the main thread.
- **Single Responsibility** — The CLI layer handles only argument parsing, path resolution, and validation. Pipeline orchestration is a separate concern.
- **Shared Error Model** *(planned)* — One unified error type used by all pipeline components. The legacy `ScanError` enum will be removed (spec 002); all call sites will use the shared model directly.
- **Single-Threaded Error Writes** — Error entries are written serially from the main processing loop. No locking required. Concurrency support deferred to a future iteration.
- **Extensible Design** — Adding a new pipeline stage requires only a new enum case; the error entry structure, logging mechanism, and persistence layer remain unchanged.

## Limitations (POC Scope)

- **No image preprocessing** — No deskewing, rotation correction, contrast enhancement, or noise reduction. Relies on Vision framework's built-in capabilities.
- **No multi-page form support** — Each image is treated as a standalone form.
- **No form classification** — The reader does not attempt to classify which type of form an image represents.
- **No field standardization** — Raw extraction only. Mapping diverse form fields to a canonical schema is deferred to a future Standardization feature.
- **No PII handling** — Forms contain personal data (names, addresses, phone numbers). **Production use would require** encryption of extracted data, access controls on `error.log` and CSV output, and compliance with applicable data protection regulations.
- **No test targets** — POC scope per project constitution.
- **No config file support** — All input is via command-line arguments and flags.
- **No colored/formatted output** — Plain unformatted text only.

## Feature Specifications

Detailed specifications are maintained in the `specs/` directory:

| Spec | Feature | Status |
|---|---|---|
| [001](specs/001-cli-progress-errors/spec.md) | CLI Progress Reporting & Error Logging | Draft |
| [002](specs/002-shared-error-model/spec.md) | Shared Error Model | Draft |
| [003](specs/003-cli-entry-point/spec.md) | CLI Entry Point | Draft |
| [004](specs/004-ocr-reader/spec.md) | OCR Reader | Draft |

### Feature Dependencies

```
003 CLI Entry Point
 ├──▶ 004 OCR Reader
 │     └──▶ (future) CSV Export adaptation
 ├──▶ 001 CLI Progress & Error Logging
 └──▶ 002 Shared Error Model
       └──▶ 004 OCR Reader (error reporting)
```

## License

*(To be determined)*
