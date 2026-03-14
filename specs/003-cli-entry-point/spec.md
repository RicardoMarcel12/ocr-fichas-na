# Feature Specification: CLI Entry Point

**Feature Branch**: `003-cli-entry-point`  
**Created**: 2026-03-11  
**Status**: Draft  
**Input**: User description: "Make the CLI interface, a runnable entry point that takes a parameter of directory or a flag --here to work within the current folder, the CLI should be invocable from anywhere."

## Clarifications

### Session 2026-03-11

- Q: Should `OcrFichasNa` conform to `AsyncParsableCommand` (async from day one) or start with synchronous `ParsableCommand` and migrate later? → A: Convert to `AsyncParsableCommand` now — async entry point from day one with `mutating func run() async throws`.
- Q: Should `AppError` absorb `ScanError` cases now, or remain minimal with only `notADirectory` for this feature? → A: Introduce minimal `AppError` with only the `notADirectory` case in this feature. The existing `ScanError` enum in `ImageScanner.swift` is left in place for now; its complete removal and migration of all call sites to the shared error model is handled exclusively by spec 002 (`shared-error-model`).
- Q: What exit code convention should the CLI follow for errors? → A: Single non-zero exit code (`1`) for all application-level errors; Swift Argument Parser uses its own exit codes for parse/validation failures.
- Q: What should `run()` do on success — print path only, or trigger the full scan/CSV pipeline? → A: Print path only — `run()` resolves & validates the directory, prints `Scanning: <path>`, then returns. Full pipeline wiring is deferred to a later integration feature.
- Q: What out-of-scope boundaries should be declared to keep the CLI entry point focused? → A: Exclude config file support, structured logging/log levels, and colored/formatted terminal output. The CLI layer follows the Single Responsibility Principle — its only job is argument parsing, path resolution, and path validation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scan a Directory by Path (Priority: P1)

A user invokes the CLI from any terminal session, passing an absolute or relative path to a directory that contains image files. The tool resolves the path, validates it is an existing directory, and confirms readiness by printing the resolved target path to standard output.

**Why this priority**: This is the primary interaction model. Without directory input, no downstream processing (OCR, CSV export) can occur.

**Independent Test**: Run `ocr-fichas-na /path/to/images` from any directory on the system. The tool prints the resolved directory path and proceeds without error.

**Acceptance Scenarios**:

1. **Given** the CLI is installed and available on `$PATH`, **When** the user runs `ocr-fichas-na ~/Pictures/scans`, **Then** the tool resolves the path to its absolute form, validates it as a directory, and prints "Scanning: /Users/\<user\>/Pictures/scans".
2. **Given** the user provides a relative path `./images`, **When** the CLI executes, **Then** the tool resolves it relative to the current working directory and proceeds.
3. **Given** the user provides a path that does not exist, **When** the CLI executes, **Then** the tool prints a human-readable error to stderr and exits with code `1`.
4. **Given** the user provides a path that points to a file (not a directory), **When** the CLI executes, **Then** the tool prints "'\<path\>' is not a directory." to stderr and exits with code `1`.

---

### User Story 2 - Scan the Current Working Directory (Priority: P1)

A user navigates to a directory containing images and runs the CLI with the `--here` flag instead of providing a path argument. The tool uses the shell's current working directory as the scan target.

**Why this priority**: Equally important as Story 1 — provides a convenience shorthand that avoids typing long paths, especially useful during interactive terminal sessions.

**Independent Test**: `cd /path/to/images && ocr-fichas-na --here`. The tool prints "Scanning: /path/to/images" and proceeds.

**Acceptance Scenarios**:

1. **Given** the user is in a directory containing image files, **When** the user runs `ocr-fichas-na --here`, **Then** the tool uses the current working directory and prints its absolute path.
2. **Given** the user is in an empty directory, **When** the user runs `ocr-fichas-na --here`, **Then** the tool prints "Scanning: \<cwd\>" and returns without error (directory content enumeration is deferred to the pipeline integration feature).

---

### User Story 3 - Mutual Exclusivity of Arguments (Priority: P1)

A user accidentally provides both a directory argument and the `--here` flag. The CLI must reject this ambiguous input with a clear validation error.

**Why this priority**: Prevents undefined behavior from conflicting inputs. Must be enforced from day one.

**Independent Test**: Run `ocr-fichas-na /some/path --here`. The tool prints a validation error and exits with a non-zero code.

**Acceptance Scenarios**:

1. **Given** the user passes both a directory argument and `--here`, **When** the CLI parses arguments, **Then** validation fails with: "Provide either a directory argument or --here, not both."
2. **Given** the user provides neither a directory argument nor `--here`, **When** the CLI parses arguments, **Then** validation fails with: "Provide a directory path or pass --here to scan the current directory."

---

### User Story 4 - Global Availability (Priority: P2)

A user builds the tool and makes it available system-wide so it can be invoked from any terminal session without specifying the full binary path.

**Why this priority**: Usability enhancement — not strictly required for the tool to work, but essential for the "invoke from anywhere" requirement.

**Independent Test**: After installation, open a new terminal window, type `ocr-fichas-na --help`, and verify the help text appears.

**Acceptance Scenarios**:

1. **Given** the user builds the project in release mode, **When** the build succeeds, **Then** a standalone binary named `ocr-fichas-na` is produced.
2. **Given** the user places the binary in a directory on `$PATH`, **When** the user opens a new shell and runs `ocr-fichas-na --help`, **Then** the help text is displayed.

---

### User Story 5 - Help Output (Priority: P2)

A user runs `ocr-fichas-na --help` or `ocr-fichas-na -h` to see usage instructions before using the tool.

**Why this priority**: Standard CLI user experience. Users expect a help command to understand how to use the tool.

**Independent Test**: Run `ocr-fichas-na --help` and verify the output includes the command name, description, argument, and flag descriptions.

**Acceptance Scenarios**:

1. **Given** the CLI is available, **When** the user runs `ocr-fichas-na --help`, **Then** the output includes: command name (`ocr-fichas-na`), a brief description of what the tool does, the `directory` argument description, and the `--here` flag description.

---

### Edge Cases

- What happens when the directory path contains spaces or special characters? → The tool must handle them correctly.
- What happens when the directory path is a symlink to a directory? → The tool should follow the symlink and scan the target directory.
- What happens when the user has no read permission on the directory? → The tool surfaces a human-readable error message on stderr and exits with code `1` (see FR-010).
- What happens on case-sensitive vs. case-insensitive file systems? → Image extension matching is deferred to the scanning/pipeline feature; the CLI entry point does not perform file enumeration.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The CLI MUST accept an optional positional argument `directory` representing a file system path.
- **FR-002**: The CLI MUST accept a `--here` flag that uses the current working directory as the scan target.
- **FR-003**: The CLI MUST validate that exactly one of `directory` or `--here` is provided; if both or neither are given, it MUST exit with a descriptive validation error.
- **FR-004**: The CLI MUST resolve the provided path (relative or absolute) to a fully-qualified absolute path.
- **FR-005**: The CLI MUST validate that the resolved path is an existing directory; if not, it MUST print a human-readable error to stderr and exit with code `1`.
- **FR-006**: The CLI MUST use `ocr-fichas-na` as the command name.
- **FR-007**: The CLI MUST include a human-readable description and usage information accessible via `--help`.
- **FR-008**: The CLI MUST provide an async entry point. On invocation, the entry point MUST resolve the target path, validate it is an existing directory, and print `Scanning: <path>` to stdout. It MUST NOT trigger the scan/CSV pipeline; pipeline integration is deferred to a later feature.
- **FR-009**: The project MUST include documentation on how to build and install the tool for global availability.
- **FR-010**: All application-level errors (e.g., invalid directory, permission errors) MUST exit with code `1`. Argument parsing and validation failures are handled by the argument parsing framework using its own exit codes; the application MUST NOT override them.

### Non-Functional Requirements

- **NFR-001**: The CLI MUST compile without warnings under the project's strict concurrency settings.
- **NFR-002**: All shared data types MUST be safe for concurrent access.
- **NFR-003**: The project MUST have only one external dependency for argument parsing.

### Key Entities

- **`OcrFichasNa`**: The main entry-point command. Owns the `directory` argument and `here` flag. Follows the Single Responsibility Principle: its only responsibilities are argument parsing, path resolution, and directory validation. It MUST NOT handle configuration loading, logging infrastructure, output formatting, or pipeline orchestration. Pipeline orchestration (scan + CSV export) is deferred to a later integration feature.
- **`AppError`**: Minimal error type introduced in this feature containing only the `notADirectory` case — raised when the user provides a path that is not a valid directory. `ScanError` remains untouched; spec 002 will handle its migration into `AppError` later.

## Implementation Notes *(non-normative)*

> These notes are intended for implementers and do not constitute normative requirements.

- **Async entry point**: FR-008's async entry-point requirement is satisfied by conforming `OcrFichasNa` to `AsyncParsableCommand` (Swift Argument Parser) with a `mutating func run() async throws` signature.
- **AppError**: A minimal error type containing only the `notADirectory` case is sufficient for this feature. `ScanError` migration is deferred to spec 002.
- **Exit code delegation**: FR-010's exit-code behaviour for argument-parsing failures is delegated to the Swift Argument Parser framework; application code MUST NOT call `exit()` directly for parse errors.
- **Concurrency**: NFR-001 and NFR-002 correspond to Swift 6 strict-concurrency mode. All command state should use value types or actor-isolated references.

## Out of Scope

- **Scan/CSV pipeline wiring**: `run()` does not invoke `ImageScanner`, `CSVWriter`, or any downstream processing. Pipeline integration will be addressed in a dedicated future feature.
- **Progress reporting or verbose output modes**: Not part of this entry-point feature.
- **Config file support**: The CLI does not read configuration from files (e.g., `.ocr-fichas-na.yml`). All input is via command-line arguments and flags.
- **Structured logging / log levels**: No logging framework, log levels (`--verbose`, `--debug`), or structured log output. The tool prints plain text to stdout/stderr only.
- **Colored or formatted terminal output**: No ANSI colors, bold text, or rich terminal formatting. Output is plain unformatted text.

## Assumptions

- The tool currently targets macOS 13+ environments. Linux support is a future goal that would require build toolchain and manifest changes.
- The user has a working build toolchain installed (e.g., Swift toolchain for this project).
- Directory paths provided by the user are on locally-mounted file systems (network mounts are not explicitly supported).
- The tool follows symlinks by default when resolving directory paths.
- Image extension matching (used in downstream features) is case-insensitive.
- Error messages are in English.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can run `ocr-fichas-na /valid/directory` and see the resolved scanning target printed without error.
- **SC-002**: A user can run `ocr-fichas-na --here` from any directory and see the current directory printed as the scanning target without error.
- **SC-003**: Running `ocr-fichas-na /valid/dir --here` exits with a non-zero code and a clear validation error within 1 second.
- **SC-004**: Running `ocr-fichas-na` with no arguments exits with a non-zero code and a clear validation error within 1 second.
- **SC-005**: Running `ocr-fichas-na /nonexistent/path` exits with code `1` and prints a human-readable "not a directory" error to stderr.
- **SC-006**: The project builds in release mode with zero warnings under strict concurrency settings.
- **SC-007**: After placing the binary on `$PATH`, the tool is runnable from any directory on the system.
