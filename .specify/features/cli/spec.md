# Feature Specification: CLI

**Feature Branch**: `cli-entry-point`  
**Created**: 2026-03-08  
**Status**: Draft  
**Input**: User description: "Make the CLI interface, a runnable entry point that takes a parameter of directory or a flag --here to work within the current folder, the CLI should be invocable from anywhere."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scan a Directory by Path (Priority: P1)

A user invokes the CLI from any terminal session, passing an absolute or relative path to a directory that contains image files. The tool resolves the path, validates it is an existing directory, and confirms readiness by printing the resolved target path to stdout.

**Why this priority**: This is the primary interaction model. Without directory input, no downstream processing (OCR, CSV export) can occur.

**Independent Test**: Run `ocr-fichas-na /path/to/images` from any directory on the system. The tool prints the resolved directory path and proceeds without error.

**Acceptance Scenarios**:

1. **Given** the CLI is installed and available on `$PATH`, **When** the user runs `ocr-fichas-na ~/Pictures/scans`, **Then** the tool resolves the path to its absolute form, validates it as a directory, and prints "Scanning: /Users/<user>/Pictures/scans".
2. **Given** the user provides a relative path `./images`, **When** the CLI executes, **Then** the tool resolves it relative to the current working directory and proceeds.
3. **Given** the user provides a path that does not exist, **When** the CLI executes, **Then** the tool prints a human-readable error to stderr and exits with a non-zero code.
4. **Given** the user provides a path that points to a file (not a directory), **When** the CLI executes, **Then** the tool prints "'\<path\>' is not a directory." to stderr and exits with a non-zero code.

---

### User Story 2 - Scan the Current Working Directory (Priority: P1)

A user navigates to a directory containing images and runs the CLI with the `--here` flag instead of providing a path argument. The tool uses the shell's current working directory as the scan target.

**Why this priority**: Equally important as Story 1 — provides a convenience shorthand that avoids typing long paths, especially useful during interactive terminal sessions.

**Independent Test**: `cd /path/to/images && ocr-fichas-na --here`. The tool prints "Scanning: /path/to/images" and proceeds.

**Acceptance Scenarios**:

1. **Given** the user is in a directory containing image files, **When** the user runs `ocr-fichas-na --here`, **Then** the tool uses the current working directory and prints its absolute path.
2. **Given** the user is in an empty directory, **When** the user runs `ocr-fichas-na --here`, **Then** the tool proceeds without error and reports zero images found.

---

### User Story 3 - Mutual Exclusivity of Arguments (Priority: P1)

A user accidentally provides both a directory argument and the `--here` flag. The CLI must reject this ambiguous input with a clear validation error.

**Why this priority**: Prevents undefined behavior from conflicting inputs. Must be enforced from day one.

**Independent Test**: Run `ocr-fichas-na /some/path --here`. The tool prints a validation error and exits with a non-zero code.

**Acceptance Scenarios**:

1. **Given** the user passes both a directory argument and `--here`, **When** the CLI parses arguments, **Then** validation fails with: "Provide either a directory argument or --here, not both."
2. **Given** the user provides neither a directory argument nor `--here`, **When** the CLI parses arguments, **Then** validation fails with: "Provide a directory path or pass --here to scan the current directory."

---

### User Story 4 - Global Availability via `swift build` + PATH (Priority: P2)

A developer builds the tool and makes it available system-wide so it can be invoked from any terminal session without specifying the full binary path.

**Why this priority**: Usability enhancement — not strictly required for the tool to work, but essential for the "invoke from anywhere" requirement.

**Independent Test**: After installation, open a new terminal window, type `ocr-fichas-na --help`, and verify the help text appears.

**Acceptance Scenarios**:

1. **Given** the user runs `swift build -c release`, **When** the build succeeds, **Then** the binary is produced at `.build/release/ocr-fichas-na`.
2. **Given** the user copies or symlinks the binary to a directory on `$PATH` (e.g., `/usr/local/bin`), **When** the user opens a new shell and runs `ocr-fichas-na --help`, **Then** the ArgumentParser-generated help text is displayed.

---

### User Story 5 - Help and Version Output (Priority: P2)

A user runs `ocr-fichas-na --help` or `ocr-fichas-na -h` to see usage instructions before using the tool.

**Why this priority**: Standard CLI UX. Swift Argument Parser provides this for free, but the command configuration must be correctly defined.

**Independent Test**: Run `ocr-fichas-na --help` and verify the output includes the abstract, usage, arguments, and flags.

**Acceptance Scenarios**:

1. **Given** the CLI is available, **When** the user runs `ocr-fichas-na --help`, **Then** the output includes: command name (`ocr-fichas-na`), abstract, the `directory` argument description, and the `--here` flag description.

---

### Edge Cases

- What happens when the directory path contains spaces or special characters? → The tool must handle them correctly via `URL(fileURLWithPath:)`.
- What happens when the directory path is a symlink to a directory? → The tool should follow the symlink and scan the target directory.
- What happens when the user has no read permission on the directory? → The tool must surface a `FileManager` error as a human-readable message on stderr.
- What happens on case-sensitive vs. case-insensitive file systems? → Image extension matching must be case-insensitive (`.JPG`, `.Png`, etc.).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The CLI MUST accept an optional positional argument `directory` of type `String` representing a file system path.
- **FR-002**: The CLI MUST accept a `--here` flag that uses the current working directory as the scan target.
- **FR-003**: The CLI MUST validate that exactly one of `directory` or `--here` is provided; if both or neither are given, it MUST exit with a descriptive validation error.
- **FR-004**: The CLI MUST resolve the provided path (relative or absolute) to a `URL` using `URL(fileURLWithPath:)`.
- **FR-005**: The CLI MUST validate that the resolved path is an existing directory; if not, it MUST print a human-readable error to stderr and exit with a non-zero code.
- **FR-006**: The CLI entry point MUST conform to `AsyncParsableCommand` from Swift Argument Parser (per Constitution Principle II).
- **FR-007**: The `run()` method MUST be declared as `mutating func run() async throws` to support structured concurrency in downstream features.
- **FR-008**: The CLI MUST use the command name `ocr-fichas-na` via `CommandConfiguration`.
- **FR-009**: The CLI MUST provide a human-readable `abstract` and `discussion` in `CommandConfiguration`.
- **FR-010**: The project MUST include instructions (in README or inline comments) on how to build the release binary and make it globally available on `$PATH`.

### Non-Functional Requirements

- **NFR-001**: The CLI MUST compile under Swift 6 with Complete Concurrency Checking enabled (Constitution Principle I).
- **NFR-002**: All types MUST conform to `Sendable` where they cross concurrency boundaries (Constitution Principle I).
- **NFR-003**: The only external dependency MUST be `apple/swift-argument-parser` (Constitution Principle V).
- **NFR-004**: No test targets or testing frameworks are required (Constitution Principle VII).

### Key Entities

- **`OcrFichasNa`**: The `@main` entry-point struct conforming to `AsyncParsableCommand`. Owns the `directory` argument and `here` flag. Orchestrates the scan pipeline in `run()`.
- **`AppError`**: Unified error enum (Constitution Principle IV). For this feature, the relevant case is `notADirectory`.

## Installation & Global Availability

The following instructions MUST be documented in the project README:

```bash
# Build the release binary
swift build -c release

# Option A: Symlink to /usr/local/bin (recommended)
ln -sf $(swift build -c release --show-bin-path)/ocr-fichas-na /usr/local/bin/ocr-fichas-na

# Option B: Copy the binary
cp $(swift build -c release --show-bin-path)/ocr-fichas-na /usr/local/bin/

# Verify
ocr-fichas-na --help
```

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `ocr-fichas-na /valid/directory` resolves the path and prints the scanning target without error.
- **SC-002**: `ocr-fichas-na --here` uses `FileManager.default.currentDirectoryPath` and prints the scanning target without error.
- **SC-003**: `ocr-fichas-na /valid/dir --here` exits with a non-zero code and a clear validation error message.
- **SC-004**: `ocr-fichas-na` (no arguments) exits with a non-zero code and a clear validation error message.
- **SC-005**: `ocr-fichas-na /nonexistent/path` exits with a non-zero code and prints "'<path>' is not a directory." to stderr.
- **SC-006**: `swift build -c release` completes with zero warnings under strict concurrency.
- **SC-007**: The binary is runnable from any directory after being placed on `$PATH`.
