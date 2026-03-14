# Feature Specification: OCR Reader

**Feature Branch**: `004-ocr-reader`  
**Created**: 2026-03-11  
**Status**: Draft  
**Input**: User description: "Create an OCR reader that reads registration-form pages (fichas). Printed text is the key, handwritten text is the value. Ignore keys with empty values. Forms are non-standard — extract raw key-value structure per image and hold it for a later standardization stage."

## Clarifications

### Session 2026-03-11

- Q: How is the minimum confidence threshold for FR-006 configured? → A: Via CLI flag `--min-confidence` (type: `Double`, default: `0.25`), passed to `OCRProcessor` at initialization.
- Q: Should error handling use standalone `AppError` cases or align with spec 002's shared error model? → A: Align with spec 002's shared error model. Errors use the unified severity levels (`WARNING`/`ERROR`/`FATAL`) and pipeline stage tags (`image-loading`, `ocr-recognition`) and are logged to `error.log`.
- Q: FR-010 says "4–8" concurrent tasks — what is the concrete value? → A: Default to `min(ProcessInfo.processInfo.activeProcessorCount, 8)` — the system's CPU core count capped at 8.
- Q: How does the system distinguish the header block from the form body? → A: The first 3–5 recognized text blocks (by vertical position) that appear above the first detected label (text ending with `:`) are treated as header candidates.
- Q: Forms contain personal data (names, addresses, phone numbers) — is PII handling required? → A: No special PII handling for POC scope. A production note documents that data protection measures would be required.

## Context: Sample Form Analysis

The target documents are **registration forms** ("fichas de inscripción") from organizations like Nueva Acrópolis. A typical form contains:

- A **printed header** block (organization name, course title, location).
- A **body** of labeled fields where the **printed label** (e.g., `Nombre:`, `Teléfono:`, `Dirección de Casa:`) acts as the **key** and the **handwritten fill-in** next to it acts as the **value**.
- Some fields are **left blank** by the person filling the form (e.g., `Carrera:` with no handwriting) — these must be discarded.
- **Checkbox sections** where a printed option is marked (e.g., `☒ Amigo`).
- **Signature and date blocks** at the bottom.
- Each form may have a **completely different layout and set of fields** from other forms in the same directory — there is no single canonical schema.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Extract Key-Value Pairs from a Single Form Image (Priority: P1)

The user points the tool at a directory containing scanned form images. For each image, the OCR reader detects all text, identifies printed labels as keys and adjacent handwritten text as values, and produces a structured in-memory representation of the form's data.

**Why this priority**: This is the core value proposition — without key-value extraction, the tool is just a raw text dump. Every downstream feature (CSV export, standardization) depends on this.

**Independent Test**: Process a single form image (like the sample "Ficha de Inscripción"). Verify the output contains entries such as `Nombre` → `Stephanie Marcela López Campos`, `Edad` → `18 años`, `Teléfono` → `2298-1949`.

**Acceptance Scenarios**:

1. **Given** a scanned form image with printed labels and handwritten values, **When** the OCR reader processes the image, **Then** it produces a `FormData` object containing an ordered list of key-value pairs where keys are the printed labels and values are the handwritten text.
2. **Given** a form with the field `Nombre: Stephanie Marcela López Campos`, **When** OCR processes it, **Then** the resulting `FormData` contains an entry with key `Nombre` and value `Stephanie Marcela López Campos`.
3. **Given** a form with multiple fields on the same logical line (e.g., `Edad 18 años` adjacent to the name field), **When** OCR processes it, **Then** each key-value pair is captured independently.

---

### User Story 2 - Discard Empty Fields (Priority: P1)

Fields where the printed label exists but no handwriting was filled in must be excluded from the output. This prevents polluting the data with meaningless empty entries.

**Why this priority**: Equally critical as Story 1 — empty fields add noise that complicates the later standardization stage. The sample form has fields like `Carrera:` left blank.

**Independent Test**: Process the sample form. Verify that `Carrera` does NOT appear in the output since it was left blank.

**Acceptance Scenarios**:

1. **Given** a form where the field `Carrera:` has no handwritten value, **When** OCR processes the image, **Then** the key `Carrera` is absent from the `FormData` output.
2. **Given** a form where all fields are filled in, **When** OCR processes the image, **Then** all key-value pairs are present in the output.
3. **Given** a form where a field has only whitespace or unrecognizable marks next to the label, **When** OCR processes it, **Then** that field is treated as empty and excluded.

---

### User Story 3 - Preserve Raw Per-Form Structure (Priority: P1)

Each form image may have a unique layout and field set. The reader must extract whatever fields are present without mapping them to a predefined schema. The raw structure is preserved for a later standardization stage.

**Why this priority**: The forms are non-standard — a rigid schema would lose data. Preserving the raw structure is essential for the downstream standardization pipeline to work across diverse form types.

**Independent Test**: Process two different forms (e.g., one with `Lugar de Trabajo` and one without). Verify each produces a `FormData` with its own unique set of keys matching the fields actually present on that specific form.

**Acceptance Scenarios**:

1. **Given** two form images with different field layouts, **When** OCR processes both, **Then** each `FormData` contains only the fields present on its respective form — no union, no intersection, no padding.
2. **Given** a form with fields not seen in any other form, **When** OCR processes it, **Then** those unique fields appear in the output with their handwritten values.
3. **Given** the `FormData` output, **When** inspected, **Then** the original field order from the form (top to bottom, left to right) is preserved.

---

### User Story 4 - Process Multiple Images in Parallel (Priority: P2)

When the directory contains many form images, the OCR reader processes them concurrently using structured concurrency to maximize throughput, while throttling to prevent memory exhaustion.

**Why this priority**: Important for performance on real workloads (directories with hundreds of scanned forms), but the core extraction logic (Stories 1–3) must work correctly first.

**Independent Test**: Process a directory with 20+ form images. Verify all are processed successfully and wall-clock time is significantly less than sequential processing.

**Acceptance Scenarios**:

1. **Given** a directory with 20 form images, **When** the OCR reader processes them, **Then** it uses structured concurrency with a maximum of `min(activeProcessorCount, 8)` concurrent tasks.
2. **Given** parallel processing, **When** one image fails to load, **Then** the error is captured for that image but other images continue processing.
3. **Given** parallel processing completes, **Then** the resulting array of `FormData` objects is sorted by file name for deterministic output.

---

### User Story 5 - Handle Checkbox and Multi-Option Sections (Priority: P3)

Some forms contain checkbox grids (e.g., "¿Cómo se enteró del curso?" with options: Amigo, Afiche, Volante, etc.). The reader should capture checked options as a key-value pair where the key is the section question and the value lists the marked option(s).

**Why this priority**: Nice-to-have for completeness. The core key-value extraction (P1) is sufficient for the MVP; checkbox handling can be refined in standardization.

**Independent Test**: Process the sample form. Verify the output contains an entry like `¿Cómo se enteró del curso?` → `Amigo`.

**Acceptance Scenarios**:

1. **Given** a form with a checkbox section where `☒ Amigo` is marked, **When** OCR processes it, **Then** the `FormData` contains an entry with the section's question as key and `Amigo` as value.
2. **Given** a checkbox section with multiple marked options, **When** OCR processes it, **Then** all marked options are captured (comma-separated or as a list in the value).

---

### User Story 6 - Capture Form Metadata from Header (Priority: P3)

The printed header block (organization name, course title, location/sede) provides context about what kind of form this is. This metadata should be captured separately from the field data.

**Why this priority**: Useful for grouping and filtering during standardization, but not blocking for the core extraction pipeline.

**Independent Test**: Process the sample form. Verify the `FormData` includes metadata entries such as `CURSO 100% FILOSOFÍA PRÁCTICA`, `SEDE ANTIGUO CUSCATLAN`.

**Acceptance Scenarios**:

1. **Given** a form with a printed header, **When** OCR processes it, **Then** the `FormData.header` property contains the recognized header text lines (the first 3–5 text blocks above the first detected label).
2. **Given** a form without a recognizable header (first text block is already a label), **When** OCR processes it, **Then** `FormData.header` is empty and no error is thrown.

---

### Edge Cases

- What happens when handwriting overlaps printed text? → The OCR reader extracts the best-confidence text and includes it; accuracy limitations are acceptable for a POC.
- What happens with very poor handwriting that the OCR engine cannot recognize? → The field is treated as empty and excluded (per Story 2 rules). A per-image confidence score is tracked.
- What happens when a label spans multiple printed lines (e.g., "Fecha y lugar de nacimiento:")? → The full multi-word label is captured as a single key.
- What happens with Spanish special characters (ñ, á, é, í, ó, ú, ü)? → The OCR engine with accurate recognition mode and Spanish language hint must handle them. If not recognized, the raw best-guess text is preserved.
- What happens when the image is rotated or skewed? → Rely on the OCR engine's built-in image orientation handling; no custom deskew logic for POC.
- What happens when a value wraps to the next physical line on the form? → Treat as part of the same value for the preceding key (best effort via spatial proximity of recognized text blocks).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The OCR reader MUST use Apple Vision framework's `VNRecognizeTextRequest` with `.accurate` recognition level (Constitution Principle V).
- **FR-002**: The OCR reader MUST set recognition languages to include `"es"` (Spanish) and `"en"` (English) to handle both printed labels and handwritten text on Latin American forms.
- **FR-003**: For each recognized text observation, the system MUST capture: the recognized string, its confidence score, and its bounding box coordinates.
- **FR-004**: The system MUST use spatial analysis (bounding-box positions and proximity) to associate printed labels (keys) with their adjacent handwritten values.
- **FR-005**: A **label** is identified as text that ends with a colon (`:`) or is immediately followed by a handwritten region. The colon MUST be stripped from the key name in the output.
- **FR-006**: Key-value pairs where the value is empty, whitespace-only, or below the minimum confidence threshold MUST be excluded from the output. The threshold is controlled by a CLI flag `--min-confidence` (type: `Double`, default: `0.25`). The flag is passed through to `OCRProcessor` at initialization.
- **FR-007**: Each processed image MUST produce a `FormData` object containing: the source file name, an optional header (top-of-form metadata), an ordered array of `FormField` key-value pairs, and an overall average confidence score.
- **FR-008**: The `FormData` fields MUST preserve the spatial reading order (top-to-bottom, left-to-right) as recognized from the image.
- **FR-009**: The OCR reader MUST conform to the `OCRProcessing` protocol (Constitution Principle II): `func process(imageURLs: [URL]) async throws -> [ImageFile]`. The method throws only for fatal, process-level errors (e.g., the `imageURLs` array is empty, or all images fail to load leaving no results to return). Per-image load failures (FR-011) and per-image OCR failures (FR-012) are NOT surfaced as throws — they are logged and processing continues for remaining images.
- **FR-010**: Parallel image processing MUST use structured concurrency with a maximum concurrent task count equal to `min(ProcessInfo.processInfo.activeProcessorCount, 8)` (i.e., the system's active CPU core count, capped at 8), consistent with Constitution Principle III.
- **FR-011**: If an image cannot be loaded from a URL, the system MUST report the failure using the shared error model from spec 002 with severity `ERROR`, pipeline stage `image-loading`, the affected file path, and a human-readable description. The error MUST be logged to `error.log` and processing MUST continue for remaining images.
- **FR-012**: If the OCR request fails, the system MUST report the failure using the shared error model from spec 002 with severity `ERROR`, pipeline stage `ocr-recognition`, the affected file path, and a description including the underlying error. The error MUST be logged to `error.log` and processing MUST continue for remaining images.
- **FR-013**: All recognized text MUST be sanitized: leading/trailing whitespace trimmed, internal newlines replaced with a single space.
- **FR-014**: The system MUST NOT attempt to normalize, standardize, or map extracted fields to any predefined schema — raw extraction only. Standardization is deferred to a separate future feature.
- **FR-015**: The header block MUST be identified by treating the first 3–5 recognized text blocks (sorted by vertical position, top-to-bottom) that appear before the first detected label (as defined in FR-005) as header candidates. These are stored in `FormData.header`. If no label is found, all text blocks are treated as form body with an empty header.

### Non-Functional Requirements

- **NFR-001**: All types (`FormData`, `FormField`, `OCRProcessor`) MUST conform to `Sendable` (Constitution Principle I).
- **NFR-002**: All source files MUST compile under Swift 6 with Complete Concurrency Checking (Constitution Principle I).
- **NFR-003**: The only external dependency is `apple/swift-argument-parser` (Constitution Principle V).
- **NFR-004**: All public types and methods MUST include `///` documentation comments (Constitution Principle VI).
- **NFR-005**: No test targets or testing frameworks are required (Constitution Principle VII).
- **NFR-006**: OCR processing MUST NOT block the main thread; all work is dispatched via structured concurrency.

### Key Entities

- **`FormData`**: Represents the complete extraction result for a single form image. Conforms to `Sendable`. Contains:
  - `fileName: String` — base name of the source image file.
  - `header: [String]` — recognized header/title lines from the top of the form (may be empty).
  - `fields: [FormField]` — ordered array of key-value pairs extracted from the form body.
  - `averageConfidence: Float` — mean confidence across all recognized observations.

- **`FormField`**: A single key-value pair from the form. Conforms to `Sendable`. Contains:
  - `key: String` — the printed label (colon stripped, trimmed).
  - `value: String` — the handwritten fill-in (trimmed, newlines sanitized).
  - `confidence: Float` — confidence score for the value recognition.

- **`OCRProcessor`**: Conforms to `OCRProcessing` protocol. Encapsulates all OCR logic. Initialized with `minConfidence: Double` (default `0.25`). Responsible for loading images, running text recognition, performing spatial analysis to pair labels with values, filtering empty fields and low-confidence values, assembling `FormData` objects internally, and populating `ImageFile` objects with the extracted OCR payload for the output contract.

- **`OCRProcessing`** *(protocol)*: Defines the contract: `func process(imageURLs: [URL]) async throws -> [ImageFile]`. `FormData` and `FormField` are internal helper types used within `OCRProcessor`; they are not part of the public protocol boundary.

## Out of Scope

- **Field standardization or normalization**: The OCR reader extracts raw key-value pairs only. Mapping diverse form fields to a canonical schema is deferred to a dedicated future Standardization feature.
- **CSV export**: Serializing `FormData` to CSV is handled by the existing `CSVExporter` — not part of this feature.
- **Image preprocessing**: No custom deskewing, rotation correction, contrast enhancement, or noise reduction. The OCR engine's built-in capabilities are relied upon.
- **Multi-page form support**: Each image is treated as a standalone form. Associating multiple pages to a single registrant is out of scope.
- **Form classification or type detection**: The reader does not attempt to classify which type of form an image represents.

## Assumptions

- Input images are scanned registration forms in common image formats (JPEG, PNG, TIFF, HEIC) supported by the platform's image loading APIs.
- Forms are primarily in Spanish with occasional English text; the dual-language recognition setting covers the expected input.
- Printed text on forms is machine-typeset (not handwritten labels) with sufficient resolution for OCR to achieve reasonable accuracy.
- The spatial layout of forms follows a general convention: labels appear to the left of or above their corresponding handwritten values.
- A colon (`:`) after printed text is a reliable heuristic for identifying a label in most forms encountered.
- The POC does not require 100% extraction accuracy — reasonable best-effort extraction is acceptable, with confidence scores provided for downstream quality assessment.
- Image files are provided as local file system paths (no network URLs or cloud storage).
- Error messages are in English.
- **PII / Data Protection**: Forms contain personal data (names, addresses, phone numbers). For POC scope, no special PII handling (encryption at rest, access controls, redaction) is implemented. **Production use would require data protection measures** including: encryption of extracted data, access control on `error.log` and CSV output, and compliance with applicable data protection regulations.

## Relationship to Other Features

- **Upstream dependency**: CLI Entry Point (spec 003) — provides the directory path and image URL list via `FileSystemManager`.
- **Upstream dependency**: Shared Error Model (spec 002) — provides the unified error types, severity levels, and pipeline stage tags used by the OCR reader for error reporting to `error.log`.
- **Downstream consumer**: `CSVExporter` — will serialize `FormData` objects to CSV. The CSV format may need to adapt to the dynamic key-value structure (future spec).
- **Future feature**: A **Standardization** stage will map diverse raw `FormData` structures to a canonical schema. This OCR Reader intentionally avoids any mapping logic to keep extraction and normalization decoupled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Processing the sample "Ficha de Inscripción" image produces a `FormData` with at least 8 non-empty key-value pairs, such as: Nombre, Edad, Fecha y lugar de nacimiento, Centro de estudios, Lugar de Trabajo, Dirección de Casa, Teléfono, Celular, E-mail, Otras aficiones, Horario.
- **SC-002**: The field `Carrera` (which is blank on the sample form) is absent from the output.
- **SC-003**: Keys do not include trailing colons (e.g., `Nombre` not `Nombre:`).
- **SC-004**: All `FormField.value` strings are free of `\n` and `\r` characters.
- **SC-005**: Processing 20 images completes in under 60 seconds on an Apple Silicon Mac.
- **SC-006**: An unreadable image file produces a structured error entry in `error.log` (per spec 002 shared error model format) — not a crash.
- **SC-007**: The project builds in release mode with zero warnings under strict concurrency settings.
- **SC-008**: Each `FormData` preserves the field order matching the top-to-bottom layout of the source form.
