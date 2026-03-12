# Feature Specification: CLI Progress Reporting & Error Logging

**Feature Branch**: `001-cli-progress-errors`  
**Created**: 2026-03-10  
**Status**: Draft  
**Input**: User description: "CLI progress reporting and error logging functionality: 1) Progress Bar: Display a progress bar in the CLI that goes from 0% to 100% as files are processed. At the end, show the number of processed files vs total number of files in the directory (e.g., '45/50 files processed'). 2) Error Logging: When OCR or any other error occurs during processing: log a human-readable error message to the CLI output (stdout/stderr), and also write the error message to an error.log file."

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

### User Story 1 - Progress Bar During File Processing (Priority: P1)

As a user running the CLI tool on a directory of image files, I want to see a visual progress bar that advances from 0% to 100% as each file is processed, so that I know the tool is actively working and can estimate how long the remaining work will take.

**Why this priority**: Without progress feedback, the user has no way to distinguish between a working tool and a hung process. This is the most critical usability improvement for the CLI experience, especially when processing large directories that may take significant time.

**Independent Test**: Can be fully tested by running the tool on a directory with multiple image files and observing that a progress bar appears, updates incrementally as each file is processed, and reaches 100% upon completion.

**Acceptance Scenarios**:

1. **Given** a directory containing 50 image files, **When** the user runs the tool on that directory, **Then** a progress bar is displayed that starts at 0% and advances incrementally as each file is processed until it reaches 100%.
2. **Given** the tool is processing files, **When** each individual file finishes processing, **Then** the progress bar updates to reflect the new percentage (e.g., after processing 25 of 50 files, the bar shows 50%).
3. **Given** a directory containing 1 image file, **When** the user runs the tool, **Then** the progress bar advances from 0% to 100% in a single step.

---

### User Story 2 - Summary After Processing (Priority: P1)

As a user, after the tool completes processing, I want to see a summary line showing how many files were successfully processed out of the total (e.g., "45/50 files processed"), so that I immediately know if any files were skipped or failed.

**Why this priority**: The summary is essential to give the user a clear completion signal and awareness of any failures. Together with the progress bar, it forms the core progress reporting capability.

**Independent Test**: Can be fully tested by running the tool on a directory and verifying the final output line contains the count of successfully processed files and the total file count.

**Acceptance Scenarios**:

1. **Given** a directory with 50 image files and all files are processed successfully, **When** processing completes, **Then** the output displays "50/50 files processed".
2. **Given** a directory with 50 image files and 5 files fail during processing, **When** processing completes, **Then** the output displays "45/50 files processed".
3. **Given** an empty directory (no image files), **When** the user runs the tool, **Then** the output displays "0/0 files processed".

---

### User Story 3 - Error Messages in CLI Output (Priority: P2)

As a user, when an error occurs during the processing of a specific file (e.g., OCR failure, unreadable file, permissions issue), I want to see a clear, human-readable error message in the terminal so that I can understand what went wrong and which file caused the issue.

**Why this priority**: Visible error messages enable users to diagnose and resolve issues themselves (e.g., fix a corrupt file, adjust permissions) without needing to dig through log files. This is the primary feedback mechanism for errors.

**Independent Test**: Can be fully tested by including a corrupt or unprocessable file in the directory, running the tool, and verifying that a descriptive error message appears in the terminal output for that specific file.

**Acceptance Scenarios**:

1. **Given** a directory containing a corrupt image file, **When** the tool processes that file and OCR fails, **Then** an error message is printed to stderr that includes the filename and a human-readable description of the error.
2. **Given** a directory with a file that cannot be read (e.g., permission denied), **When** the tool attempts to process that file, **Then** an error message is printed to stderr that includes the filename and describes the access issue.
3. **Given** multiple files fail during processing, **When** processing completes, **Then** each failed file has its own separate error message in the terminal output.
4. **Given** an error occurs on one file, **When** processing continues to the next file, **Then** the tool does not stop—it continues processing remaining files (graceful degradation).

---

### User Story 4 - Error Log File (Priority: P2)

As a user, when errors occur during processing, I want those errors to also be written to an `error.log` file in the target directory, so that I can review them later or share them for troubleshooting.

**Why this priority**: The log file provides a persistent record of errors that may scroll off the terminal. It complements the CLI error messages and is essential for post-processing analysis or sharing with support.

**Independent Test**: Can be fully tested by running the tool on a directory containing files that trigger errors, then checking that an `error.log` file exists in the target directory with the expected error entries.

**Acceptance Scenarios**:

1. **Given** a directory where OCR errors occur on some files, **When** processing completes, **Then** an `error.log` file is created in the target directory containing entries for each failed file.
2. **Given** a processing run with no errors, **When** processing completes, **Then** no `error.log` file is created (or an existing one is not modified).
3. **Given** an `error.log` file already exists from a previous run, **When** a new processing run produces errors, **Then** the new errors are appended to the existing file (not overwriting previous entries).
4. **Given** an error log entry, **When** the user reads the `error.log` file, **Then** each entry includes a timestamp, the filename that caused the error, and a human-readable error description.

---

### Edge Cases

- What happens when the directory contains zero image files? The progress bar should handle an empty set gracefully (no division-by-zero), and the summary should display "0/0 files processed".
- What happens when the tool does not have write permission to create or append to `error.log`? The tool should still display errors on stderr and warn the user that the log file could not be written.
- What happens when all files fail? The progress bar should still advance to 100%, and the summary should show "0/N files processed" with all errors logged.
- What happens if the terminal does not support progress bar rendering (e.g., output is piped to a file)? The progress bar is suppressed entirely; only the final summary line is printed.
- What happens with very large directories (thousands of files)? The progress bar should update efficiently without flooding the terminal with output.
- What happens if the user presses Ctrl+C (SIGINT) during processing? The tool traps the signal, flushes any pending `error.log` entries to disk, and exits.
- What happens when some files fail but others succeed? The CSV output file is still produced containing the results of all successful files. The exit code is 1 to signal that not everything was clean.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST display a visual progress bar on the terminal that advances from 0% to 100% as each file in the directory is processed.
- **FR-002**: The progress bar MUST update after each individual file is processed, reflecting the ratio of completed files to total files.
- **FR-003**: Upon completion of all file processing, the system MUST display a summary line in the format "{successful}/{total} files processed" (e.g., "45/50 files processed").
- **FR-004**: When an error occurs during the processing of a file, the system MUST print a human-readable error message to stderr that includes the filename and a description of the error.
- **FR-005**: When an error occurs during the processing of a file, the system MUST attempt to write an entry to an `error.log` file in the target directory containing a UTC timestamp in ISO 8601 format with Z suffix (e.g., `2026-03-10T14:30:00Z`), the filename, and a human-readable error description. If the `error.log` file is not writable, the system MUST still display the error on stderr and warn the user that the log file could not be written (see also FR-010).
- **FR-006**: The system MUST continue processing remaining files after encountering an error on any individual file (graceful degradation; no early termination).
- **FR-007**: If an `error.log` file already exists in the target directory, the system MUST append new error entries rather than overwriting the file.
- **FR-008**: If no errors occur during a processing run, the system MUST NOT create or modify an `error.log` file.
- **FR-009**: When the terminal output is not a TTY (e.g., piped or redirected to a file), the system MUST suppress the progress bar entirely and only print the final summary line.
- **FR-010**: If the system cannot write to the `error.log` file (e.g., due to permissions), it MUST still display the error messages on stderr and warn the user that the log file could not be written.
- **FR-011**: The system MUST exit with code 0 if all files are processed successfully, and exit with code 1 if any file fails during processing.
- **FR-012**: The system MUST always produce the CSV output file containing the results of all successfully processed files, regardless of whether some files failed. Partial success still yields an output file.
- **FR-013**: The system MUST trap SIGINT (Ctrl+C) and, upon receiving the signal, flush all pending `error.log` entries to disk before exiting.

### Key Entities

- **Processing Progress**: Represents the state of the batch processing operation—total file count, files processed so far, files succeeded, and files failed.
- **Error Entry**: Represents a single error event—timestamp of the error, filename that caused it, and a human-readable description of the failure.
- **Error Log**: A persistent, append-only text file (`error.log`) located in the target directory that collects error entries across runs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can see processing progress at all times during execution—the progress indicator updates at least once per file processed.
- **SC-002**: Upon completion, users can determine the success rate of a processing run within 2 seconds by reading the summary line (e.g., "45/50 files processed").
- **SC-003**: When file processing errors occur, 100% of errors are reported to the terminal (stderr), and the system attempts to append each error to the `error.log` file, emitting a warning to stderr if the log is not writable.
- **SC-004**: Each error message is actionable—it identifies the specific file that failed and describes the problem in terms the user can act on (e.g., "Permission denied", "Unreadable image format").
- **SC-005**: The tool processes all files in the directory regardless of individual file failures—no files are silently skipped without reporting.
- **SC-006**: The `error.log` file preserves error history across multiple runs, enabling users to track recurring issues over time.
- **SC-007**: On a directory of 1,000+ image files, the progress bar does not degrade the user experience (no flickering, excessive output, or noticeable slowdown).

## Assumptions

- The progress bar tracks file-level processing granularity (one update per file), not sub-file stages (e.g., OCR recognition phases within a single file).
- Error messages follow a consistent format: `[TIMESTAMP] ERROR: filename — description`.
- The `error.log` file uses plain text format (one entry per line or block) for easy reading with standard tools (cat, grep, tail).
- "Processed successfully" means the file completed the full OCR and CSV-writing pipeline without throwing an error.
- Timestamps in error log entries use UTC in ISO 8601 format with Z suffix (`2026-03-10T14:30:00Z`).
- The tool uses two exit codes: 0 (all files processed successfully) and 1 (one or more files failed). The CSV output file is always written with successful results regardless of exit code.
- On SIGINT (Ctrl+C), the tool performs a graceful shutdown: flushes pending `error.log` entries to disk, then exits. No attempt is made to complete in-progress file processing.

## Clarifications

### Session 2026-03-10

- Q: What progress bar implementation strategy should be used? → A: Build a minimal custom progress bar with in-place line updates. No external dependency.
- Q: How should the progress bar behave when output is not a TTY (e.g., piped)? → A: Silent — suppress the progress bar entirely when not a TTY; only print the final summary line.
- Q: What timezone should error log timestamps use? → A: UTC — all timestamps in ISO 8601 UTC format with Z suffix (e.g., `2026-03-10T14:30:00Z`).
- Q: What exit code should the tool return on partial failure? → A: Exit 0 only if all files succeed; exit 1 if any file fails. The CSV output file is always produced with whatever files succeeded, regardless of failures.
- Q: How should the tool handle Ctrl+C / SIGINT? → A: Trap SIGINT, flush pending `error.log` entries to disk, then exit immediately.

### Implementation Notes

> The following notes capture implementation-specific decisions from the Q&A session above. They are informational and **not** normative requirements. Implementations are free to use alternative approaches provided the observable behavior matches the requirements.

- **Progress bar rendering**: A minimal custom renderer using ANSI escape codes (`\r` carriage return for in-place line updates) was agreed upon. No external dependency is required.
