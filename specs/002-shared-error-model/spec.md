# Feature Specification: Shared Error Model

**Feature Branch**: `002-shared-error-model`  
**Created**: 2026-03-10  
**Status**: Draft  
**Input**: User description: "Shared Error Model for the OCR application. A unified error model that covers error processing at ALL stages of the OCR pipeline and records them ALL in a single error.log file that persists after the process has stopped or has been interrupted (SIGINT/crash)."

## Clarifications

### Session 2026-03-10

- Q: What serialization format should each error log entry use? → A: Bracket-tagged format: `[TIMESTAMP] [SEVERITY] [STAGE] FILE — DESCRIPTION`. Example: `[2026-03-10T14:30:00Z] [ERROR] [image-loading] photo.jpg — Could not decode image`
- Q: Where should error.log be written when the target directory is invalid (does not exist or is inaccessible)? → A: Fall back to the current working directory (CWD) where the user invoked the tool.
- Q: What format should the run separator line use? → A: Comment-style: `# --- Run started: 2026-03-10T14:30:00Z ---`
- Q: How should the existing `ScanError` enum be migrated to the shared error model? → A: Remove `ScanError` entirely. All call sites use the shared error model directly. No incompatible error formats coexist.
- Q: What concurrency model should the error writer use? → A: Single-threaded serial writes. The error writer assumes serial access (matches current sequential pipeline). Concurrency can be added later if needed.

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Consistent Error Reporting Across All Pipeline Stages (Priority: P1)

As a user running the OCR tool on a directory of image files, I want every error — whether it occurs during file discovery, image loading, OCR recognition, CSV writing, or output generation — to be captured in the same structured format and written to a single `error.log` file, so that I can review all problems from a single place without guessing which stage failed or parsing different formats.

**Why this priority**: Without a unified error model, errors from different stages may be reported inconsistently or silently swallowed. This is the foundational capability: a single, consistent error format used everywhere in the pipeline. All other stories depend on this.

**Independent Test**: Can be fully tested by deliberately introducing errors at each pipeline stage (e.g., a missing directory for file discovery, a corrupt file for image loading, an unrecognizable image for OCR, a read-only output path for CSV writing) and verifying that every error appears in `error.log` with identical structure and all required fields populated.

**Acceptance Scenarios**:

1. **Given** a directory that does not exist, **When** the tool attempts file discovery, **Then** an error entry is written to `error.log` that includes the pipeline stage ("file-discovery"), a timestamp, and a human-readable description.
2. **Given** a directory containing a corrupt image file that cannot be loaded, **When** the tool processes that file, **Then** an error entry is written to `error.log` with the pipeline stage ("image-loading"), the filename, a timestamp, and a description of the loading failure.
3. **Given** an image that the OCR engine cannot recognize, **When** the tool attempts OCR on that file, **Then** an error entry is written to `error.log` with the pipeline stage ("ocr-recognition"), the filename, a timestamp, and a description of the recognition failure.
4. **Given** the CSV output path is not writable, **When** the tool attempts to write results, **Then** an error entry is written to `error.log` with the pipeline stage ("csv-writing"), a timestamp, and a description of the write failure.
5. **Given** multiple errors occur across different pipeline stages in a single run, **When** the user reviews `error.log`, **Then** all error entries share the same structured format regardless of which stage produced them.

---

### User Story 2 - Error Severity Classification (Priority: P1)

As a user, I want each error to carry a severity level (warning, error, or fatal) so that I can quickly triage which problems are informational, which caused individual file failures, and which halted the entire process.

**Why this priority**: Severity classification is essential for triage. Without it, a user cannot distinguish between a minor warning (e.g., a skipped file with an unusual extension) and a fatal error (e.g., the output directory is completely inaccessible). This directly impacts how the user responds to the error log.

**Independent Test**: Can be fully tested by triggering errors of each severity level and verifying that the `error.log` entries correctly label each with its severity.

**Acceptance Scenarios**:

1. **Given** a non-critical issue occurs (e.g., a file is skipped because it has an unrecognized extension but is in the image directory), **When** the error is logged, **Then** the entry has severity "warning" and the tool continues processing all remaining files.
2. **Given** a file-level failure occurs (e.g., OCR fails on a specific image), **When** the error is logged, **Then** the entry has severity "error" and the tool continues processing the remaining files.
3. **Given** a process-level failure occurs (e.g., the output directory does not exist or is not writable), **When** the error is logged, **Then** the entry has severity "fatal" and the tool stops processing after recording the error.
4. **Given** a run that produces warnings, errors, and a fatal error, **When** the user reviews `error.log`, **Then** each entry clearly shows its severity level, and the user can filter by severity using standard text tools (e.g., grep "FATAL").

---

### User Story 3 - Error Log Persistence on Interruption or Crash (Priority: P1)

As a user, I want the `error.log` file to contain all errors captured up to the point of interruption — even if I press Ctrl+C or the process crashes — so that I never lose diagnostic information.

**Why this priority**: If error data is buffered in memory and lost on interruption, the user has no way to diagnose what went wrong. Persistence guarantees are critical for a diagnostic tool, especially during long-running batch operations where crashes or interruptions are common.

**Independent Test**: Can be fully tested by running the tool on a large directory with some bad files, pressing Ctrl+C midway through processing, and verifying that `error.log` contains all errors that occurred before the interruption.

**Acceptance Scenarios**:

1. **Given** the tool is processing files and errors have occurred, **When** the user presses Ctrl+C (SIGINT), **Then** all previously captured errors are present in `error.log` on disk.
2. **Given** the tool is processing files and errors have occurred, **When** the process completes normally, **Then** all errors are present in `error.log` on disk.
3. **Given** the tool encounters a fatal error that causes it to stop, **When** the process exits, **Then** the fatal error and all previously captured errors are present in `error.log` on disk.
4. **Given** no errors have occurred, **When** the user presses Ctrl+C, **Then** no `error.log` file is created (or an existing one is not modified).

---

### User Story 4 - Reusable Error Model Across Codebase (Priority: P2)

As a developer working on the OCR tool, I want a single shared error model (types and definitions) that all pipeline components use, so that I do not need to define error handling differently in each module and can ensure consistency by design.

**Why this priority**: A reusable error model prevents inconsistency between components and reduces duplication. While less visible to end users than the other stories, it is the architectural foundation that makes consistent error reporting possible and maintainable.

**Independent Test**: Can be fully tested by verifying that every pipeline component (file discovery, image loading, OCR recognition, CSV writing, output generation) creates errors using the shared error model, and that no component defines its own incompatible error format.

**Acceptance Scenarios**:

1. **Given** the shared error model defines the required fields (timestamp, severity, pipeline stage, affected file, description), **When** any pipeline component needs to report an error, **Then** it uses the shared model to construct the error entry.
2. **Given** a new pipeline stage is added in the future, **When** a developer needs to report errors from that stage, **Then** they can use the existing shared error model without defining new error types.
3. **Given** the error model is shared, **When** two different pipeline stages produce errors, **Then** both errors are structurally identical (same fields, same format) and differ only in their content values.

---

### User Story 5 - Error Log Append Across Runs (Priority: P2)

As a user who runs the tool multiple times on the same directory, I want the `error.log` file to accumulate errors across runs so that I can track recurring issues over time without manually preserving log files.

**Why this priority**: Append behavior is important for iterative workflows where a user fixes some files and re-runs the tool. Losing previous error history would force the user to manually back up logs.

**Independent Test**: Can be fully tested by running the tool twice on the same directory (with errors in each run) and verifying that `error.log` contains entries from both runs, separated by a clear run boundary.

**Acceptance Scenarios**:

1. **Given** an `error.log` file exists from a previous run, **When** the tool runs again and new errors occur, **Then** the new errors are appended to the existing file.
2. **Given** an `error.log` file exists from a previous run, **When** the tool runs again and no errors occur, **Then** the existing file is not modified.
3. **Given** the tool starts a new run, **When** errors are appended to `error.log`, **Then** a run separator (including the run start timestamp) is written before the first error of the new run, making it easy to distinguish errors from different runs.

---

### Edge Cases

- What happens when the `error.log` file itself cannot be created or written to (e.g., permissions, disk full)? The tool should still report errors to stderr and warn the user that the log file could not be written. Errors must not be silently lost.
- What happens when the target directory does not exist or is inaccessible? The system falls back to writing `error.log` in the current working directory (CWD). If the CWD is also not writable, errors are reported to stderr only.
- What happens when the same file causes errors at multiple pipeline stages (e.g., image loads but OCR fails and then CSV writing fails for that record)? Each error is logged as a separate entry with its respective pipeline stage.
- What happens when the error description contains special characters, newlines, or very long text? The error entry format must handle multi-line descriptions gracefully without corrupting subsequent entries. Descriptions should be single-line; newlines within a description are replaced with spaces or escaped.
- What happens when thousands of errors occur in a single run (e.g., an entire directory of corrupt files)? The `error.log` must not grow in an unbounded in-memory buffer; errors should be flushed to disk promptly via single-threaded serial writes.
- What happens when a SIGINT arrives while an error entry is being written to disk? The partially written entry should not corrupt previously written entries. Since writes are single-threaded and serial, the system uses line-buffered writes so that at most one incomplete line can exist at the end of the file.
- What happens when the process crashes due to an unhandled exception (not SIGINT)? All errors flushed to disk before the crash are preserved. The system makes best-effort to minimize unflushed data.
- What happens when the tool is run with no files to process? No errors are generated, no `error.log` is created.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST define a shared error model that all pipeline components use to report errors. The model MUST include the following fields for every error entry: timestamp, severity, pipeline stage, affected file (if applicable), and human-readable description.
- **FR-002**: The system MUST support exactly three severity levels, implemented as a Swift enum with cases: `.warning` (non-critical issue, processing continues), `.error` (file-level failure, processing continues for other files), and `.fatal` (process-level failure, processing stops after recording the error). When serialized to `error.log`, these MUST be written in uppercase: `WARNING`, `ERROR`, and `FATAL` respectively (as required by FR-005).
- **FR-003**: The system MUST define the following pipeline stages, and every error MUST be tagged with one of them: "file-discovery", "image-loading", "ocr-recognition", "csv-writing", "output-generation".
- **FR-004**: The system MUST record all errors — from all pipeline stages and all severity levels — in a single `error.log` file located in the **input directory** (the directory of image files passed as the argument to the tool; this is distinct from the CSV output path, which may point to a different location). If the input directory does not exist or is inaccessible, the system MUST fall back to writing `error.log` in the current working directory (CWD) where the user invoked the tool. If the CWD is also not writable, errors MUST be reported to stderr only (see FR-012).
- **FR-005**: Each error entry in `error.log` MUST be serialized in bracket-tagged format: `[TIMESTAMP] [SEVERITY] [STAGE] FILE — DESCRIPTION`. The timestamp MUST be UTC ISO 8601 with Z suffix (e.g., `2026-03-10T14:30:00Z`), severity MUST be uppercase (`WARNING`, `ERROR`, `FATAL`), stage MUST be the pipeline stage identifier, file MUST be the affected filename (or `N/A` if no specific file is involved), and description MUST be a human-readable message. Example: `[2026-03-10T14:30:00Z] [ERROR] [image-loading] photo.jpg — Could not decode image`.
- **FR-006**: All error entries MUST follow the bracket-tagged format defined in FR-005 (`[TIMESTAMP] [SEVERITY] [STAGE] FILE — DESCRIPTION`), regardless of which pipeline stage produced them.
- **FR-007**: The system MUST flush each error entry to disk immediately after it is written (per-entry flush), so that errors are persisted even if the process is interrupted between entries.
- **FR-008**: The system MUST trap SIGINT (Ctrl+C) and ensure all captured error entries are flushed to `error.log` before exiting.
- **FR-009**: On normal process completion, the system MUST ensure all error entries have been written to `error.log` before exiting.
- **FR-010**: If the `error.log` file already exists, the system MUST append new entries rather than overwriting the file.
- **FR-011**: If no errors occur during a processing run, the system MUST NOT create or modify an `error.log` file.
- **FR-012**: When the system cannot write to `error.log` (e.g., permissions, disk full), it MUST still report errors to stderr and warn the user that the log file could not be written.
- **FR-013**: When a new run begins and errors occur, the system MUST write a comment-style run separator line before the first error entry of that run: `# --- Run started: <TIMESTAMP> ---` where `<TIMESTAMP>` is the run start time in UTC ISO 8601 format with Z suffix (e.g., `# --- Run started: 2026-03-10T14:30:00Z ---`). This allows users to distinguish errors from different runs and is parseable by grep/awk.
- **FR-014**: The error model MUST be reusable — all pipeline components (file discovery, image loading, OCR recognition, CSV writing, output generation) MUST use the same shared error types to construct error entries. No component may define its own incompatible error format. The existing `ScanError` enum in `ImageScanner.swift` MUST be removed entirely; all call sites that previously used `ScanError` MUST be migrated to use the shared error model directly.
- **FR-015**: The system MUST support tagging errors with additional context: for "warning" severity, the DESCRIPTION field SHOULD include the reason the item was skipped; for "error" severity, the DESCRIPTION field MUST include the failure reason (the affected filename is already captured in the FILE field of FR-005); for "fatal" severity, the DESCRIPTION field MUST begin with the prefix `"Processing stopped:"` followed by the failure reason (e.g., `Processing stopped: Output directory is not writable`). The pipeline stage at which processing stopped is captured by the existing `[STAGE]` field in the FR-005 format and does not require a separate field.
- **FR-016**: Error entries MUST be written in a way that a partially written entry (e.g., due to crash during write) does not corrupt previously written entries. Each entry MUST be self-contained on exactly one physical line (terminated by a single newline character `\n`). Newlines within a description MUST be replaced with a space before the entry is written.
- **FR-017**: The error model MUST be extensible — it should be possible to add new pipeline stages or severity-relevant metadata in the future without changing the core error structure.
- **FR-018**: The error writer MUST assume single-threaded serial access. All error entries are written sequentially from the main processing loop. No locking or thread-safety mechanism is required for the initial implementation. Concurrency support may be added in a future iteration if the pipeline becomes parallel.

### Key Entities

- **Error Entry**: A single error event captured during processing. Attributes: timestamp (UTC ISO 8601 with Z suffix), severity (`WARNING`/`ERROR`/`FATAL`), pipeline stage (file-discovery, image-loading, ocr-recognition, csv-writing, output-generation), affected file (filename or `N/A`), and human-readable description. Serialized as bracket-tagged format: `[TIMESTAMP] [SEVERITY] [STAGE] FILE — DESCRIPTION`. Each entry occupies a single line and is self-contained.
- **Pipeline Stage**: An enumerated label identifying where in the OCR processing pipeline an error originated. Defined stages: file-discovery (locating and validating input files), image-loading (reading image data from disk), ocr-recognition (performing text recognition on an image), csv-writing (serializing results to CSV), output-generation (producing final output artifacts).
- **Severity Level**: A classification of the impact of an error. `WARNING`: informational, processing continues normally. `ERROR`: a specific file failed, processing continues for remaining files. `FATAL`: a systemic failure, processing stops after logging, consistent with spec 001's requirement that the tool continues after individual file failures.
- **Error Log**: The persistent, append-only `error.log` file. Primary location: the input directory (the directory of image files passed as the tool argument). Fallback location: the current working directory (CWD) if the input directory is invalid. Accumulates error entries across multiple runs, separated by run markers. Serves as the single source of truth for all errors produced by the tool. Written via single-threaded serial access.
- **Run Separator**: A comment-style marker line written to the error log at the start of a new run (before the first error of that run). Format: `# --- Run started: <TIMESTAMP> ---` (e.g., `# --- Run started: 2026-03-10T14:30:00Z ---`). Written lazily — only when the first error of a run occurs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of errors across all five pipeline stages (file-discovery, image-loading, ocr-recognition, csv-writing, output-generation) are captured in `error.log` — no error is silently dropped.
- **SC-002**: Every error entry in `error.log` contains all five required fields (timestamp, severity, pipeline stage, affected file, description) — 0% of entries are missing any field.
- **SC-003**: A user can identify the severity of any error within 2 seconds of reading the log entry, without needing to cross-reference other documentation.
- **SC-004**: A user can filter `error.log` by severity or pipeline stage using standard text tools (e.g., grep) in a single command.
- **SC-005**: After a SIGINT interruption, 100% of errors captured before the interruption are present in the `error.log` file on disk.
- **SC-006**: The error log preserves history across runs — errors from previous runs are never lost or overwritten, and run boundaries are clearly identifiable.
- **SC-007**: On a directory with 1,000+ files where 50% produce errors, all 500+ errors are flushed to disk without accumulating in an unbounded in-memory buffer.
- **SC-008**: Adding a new pipeline stage to the error model requires changes only to the stage enumeration — no changes to the error entry structure, logging mechanism, or persistence layer.

## Assumptions

- This specification covers the error model architecture (shared types, categories, pipeline coverage, and persistence guarantees). The user-facing CLI behavior (progress bar, stderr output formatting) is covered by spec 001 (`001-cli-progress-errors`) and is complementary to this spec.
- The `error.log` file is plain text, human-readable, and parseable with standard Unix text tools (cat, grep, tail, awk). It is not a binary or database format.
- Timestamps use UTC in ISO 8601 format with Z suffix (e.g., `2026-03-10T14:30:00Z`), consistent with spec 001.
- The `error.log` file is located in the input directory (the directory of image files being processed, i.e., the directory passed as the tool argument; this is distinct from the CSV output path), consistent with spec 001. If the input directory is invalid (does not exist or is inaccessible), `error.log` falls back to the current working directory (CWD).
- Error entries are serialized in bracket-tagged format: `[TIMESTAMP] [SEVERITY] [STAGE] FILE — DESCRIPTION`. This format supports grep/awk filtering by field and is human-readable.
- Run separators use comment-style format: `# --- Run started: <TIMESTAMP> ---`. The `#` prefix makes them easily distinguishable from error entries and filterable.
- The error model's five pipeline stages correspond to the current codebase structure: `ImageScanner.scan()` → file-discovery/image-loading, OCR processing → ocr-recognition, `CSVWriter.write()` → csv-writing, and final output assembly → output-generation.
- "Fatal" errors cause the tool to stop processing and exit after logging, while "warning" and "error" severities allow processing to continue (graceful degradation), consistent with spec 001's requirement that the tool continues after individual file failures.
- The error model is designed to be reusable: all current and future pipeline components use the same shared types. The existing `ScanError` enum in `ImageScanner.swift` will be removed entirely and all call sites migrated to use the shared error model directly.
- Each error entry is written as a single logical line so that appending is safe under interrupted writes.
- The run separator is written lazily — only when the first error of a run occurs, not on every run. This ensures clean runs leave the log untouched.
- The error writer uses single-threaded serial writes, matching the current sequential pipeline. No locking or concurrency mechanisms are required. Concurrency support is deferred to a future iteration if the pipeline becomes parallel.
