<!--
Sync Impact Report
──────────────────
Version change: 1.0.1 → 1.1.0
Modified principles: None
Added sections: Principle VII (No Testing Requirements — POC Scope)
Removed sections: None
Modified sections: Development Workflow (removed testing references)
Templates requiring updates:
  - .specify/templates/plan-template.md        — ✅ no changes needed (generic)
  - .specify/templates/spec-template.md        — ✅ no changes needed (generic)
  - .specify/templates/tasks-template.md       — ✅ no changes needed (generic)
  - .specify/templates/checklist-template.md   — ✅ no changes needed (generic)
  - .specify/templates/agent-file-template.md  — ✅ no changes needed (generic)
Follow-up TODOs: None
-->

# ocr-fichas-na Constitution

## Core Principles

### I. Swift 6 Strict Concurrency

All source files MUST compile under Swift 6 with Complete Concurrency
Checking enabled. The deployment target is macOS 13+. Every type that
crosses a concurrency boundary MUST conform to `Sendable`. No
`@unchecked Sendable` escape hatches are permitted without explicit,
documented justification reviewed in PR.

**Rationale:** Strict concurrency eliminates data races at compile time,
which is critical for a tool that processes images in parallel.

### II. Protocol-Oriented Architecture

The application MUST be structured around three protocol-driven
components:

- **`FileSystemManaging`** protocol / `FileSystemManager` —
  directory traversal and image-extension filtering.
- **`OCRProcessing`** protocol / `OCRProcessor` — Vision framework
  text-recognition logic.
- **`CSVExporting`** protocol / `CSVExporter` — CSV formatting and
  file writing.

The CLI entry point MUST use `AsyncParsableCommand` from Swift
Argument Parser. Object-Oriented and Protocol-Oriented design
patterns are the primary paradigms; free functions are acceptable
only for trivial utilities.

**Rationale:** Protocol-driven boundaries enable isolated testing
of each subsystem and clear separation of concerns.

### III. Structured Concurrency & Performance

All concurrent work MUST use Swift Structured Concurrency
(`async`/`await`). Parallel image processing MUST be implemented
with `TaskGroup`. Concurrent OCR tasks MUST be throttled to a
maximum of 4–8 simultaneous tasks to prevent memory pressure on
large directories.

Unstructured concurrency (`Task { }`, `Task.detached`) is
prohibited unless no structured alternative exists, and any such
usage MUST include a code comment explaining why.

**Rationale:** Structured concurrency guarantees automatic
cancellation propagation and bounded resource usage, both essential
for processing arbitrarily large image directories.

### IV. Robust Error Handling

A unified `AppError` enum conforming to `Swift.Error` MUST be the
sole top-level error type. It MUST include at minimum:

- `notADirectory`
- `fileSizeUnavailable`
- `ocrFailed`
- `imageLoadFailed`
- `csvWriteFailed`

`Result` types SHOULD be used at API boundaries where callers need
explicit success/failure semantics. Errors MUST propagate to the CLI
layer and produce human-readable messages on `stderr`.

**Rationale:** A single error enum prevents stringly-typed errors,
simplifies diagnostics, and keeps the CLI output contract clean.

### V. Minimal Dependencies

The project MUST depend exclusively on
`apple/swift-argument-parser` as its only external package. OCR MUST
be performed through the native Apple Vision framework
(`VNRecognizeTextRequest`). No third-party OCR, image-processing,
or CSV libraries are permitted.

**Rationale:** Minimizing external dependencies reduces supply-chain
risk, simplifies builds, and leverages Apple's optimized on-device
ML models.

### VI. Clean Code & Swift API Design Guidelines

- All public types, methods, and properties MUST include
  Docblock-style (`///`) documentation comments.
- `guard` statements MUST be used for early exits; deeply nested
  `if-let` chains are prohibited.
- Names MUST follow the
  [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/):
  clarity at the point of use, no abbreviations, descriptive
  parameter labels.
- All types crossing concurrency boundaries MUST be marked
  `Sendable`.

**Rationale:** Consistent style reduces cognitive load and makes
the codebase approachable for contributors unfamiliar with the
project.

### VII. No Testing Requirements (POC Scope)

This project is currently a **proof of concept (POC)**. Unit tests,
integration tests, end-to-end tests, and any other form of
automated testing are explicitly **NOT required**. No test targets,
test plans, or testing frameworks MUST be added to the project.

Contributors MUST NOT be blocked from merging due to missing test
coverage. If the project evolves beyond POC status, this principle
MUST be amended or removed via the Governance amendment procedure
before any testing requirements are introduced.

**Rationale:** As a POC, the priority is rapid iteration and
validating the core OCR pipeline. Testing overhead is deferred
until the project is promoted to production scope.

## Data Model & Output Contract

The canonical data model is the `ImageFile` struct, which MUST
conform to `Sendable` and contain:

| Property        | Type                   | Description                                          |
|-----------------|------------------------|------------------------------------------------------|
| `fileName`      | `String`               | Base name of the source image file                   |
| `ocrPayload`    | `[(key: String, value: String, confidence: Float)]` | Ordered key-value pairs extracted from the form, each with an individual confidence score |
| `averageConfidence` | `Float`            | Mean confidence across all recognized observations   |

The `ocrPayload` array preserves the top-to-bottom field order of the
source form. Keys MUST NOT include trailing colons. Values MUST NOT
contain `\n` or `\r` characters.

CSV output MUST use a **pipe (`|`) delimiter** with **UTF-8 + BOM**
encoding. The column layout MUST follow a **union-of-all-keys**
strategy — every unique key found across all `ImageFile` objects
becomes a column. Three priority columns (`Nombre`, `Email`,
`Teléfono`) MUST always appear first (in that order); remaining
columns follow in alphabetical order; a final `Average Confidence`
column closes each row. The first row MUST be a header row. Fields
MUST NOT be quoted; any pipe characters in field values MUST be
stripped before writing.

## Development Workflow & Code Style

- The project uses Swift Package Manager exclusively; Xcode project
  files MUST NOT be committed.
- `swift build` MUST succeed with zero warnings under
  `-strict-concurrency=complete`.
- Code reviews MUST verify compliance with all seven Core Principles
  before merging.

## Governance

This constitution is the authoritative source of architectural and
process rules for the **ocr-fichas-na** project. In any conflict
between this document and ad-hoc decisions, this document prevails.

**Amendment procedure:**

1. Propose changes via a pull request modifying this file.
2. All active contributors MUST review and approve.
3. Version MUST be incremented per Semantic Versioning:
   - **MAJOR** — principle removal or backward-incompatible
     redefinition.
   - **MINOR** — new principle or materially expanded guidance.
   - **PATCH** — wording clarifications, typo fixes, non-semantic
     refinements.
4. `LAST_AMENDED_DATE` MUST be updated to the merge date.

**Compliance review:** Every pull request MUST include a brief
constitution-compliance note confirming adherence to the seven Core
Principles.

**Version**: 1.1.0 | **Ratified**: 2026-03-07 | **Last Amended**: 2026-03-07
