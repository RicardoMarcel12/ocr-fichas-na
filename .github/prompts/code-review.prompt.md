# Code Review Checklist — ocr-fichas-na Constitution Compliance

When reviewing a pull request for this project, verify each of the following items derived from the [project constitution](.specify/memory/constitution.md). The PR **MUST NOT** be merged until every applicable item is confirmed.

---

## Principle I — Swift 6 Strict Concurrency

- [ ] Code compiles under **Swift 6** with Complete Concurrency Checking enabled.
- [ ] Deployment target remains **macOS 13+**.
- [ ] Every type that crosses a concurrency boundary conforms to `Sendable`.
- [ ] No `@unchecked Sendable` is used without an explicit, documented justification in the PR description.

## Principle II — Protocol-Oriented Architecture

- [ ] The three protocol-driven boundaries are respected: **`FileSystemManaging`**, **`OCRProcessing`**, **`CSVExporting`**.
- [ ] The CLI entry point uses `AsyncParsableCommand` from Swift Argument Parser.
- [ ] Object-Oriented and Protocol-Oriented patterns are the primary paradigms; free functions are used only for trivial utilities.
- [ ] No new component is introduced without a corresponding protocol abstraction.

## Principle III — Structured Concurrency & Performance

- [ ] All concurrent work uses Swift Structured Concurrency (`async`/`await`).
- [ ] Parallel image processing uses `TaskGroup`.
- [ ] Concurrent OCR tasks are throttled to **4–8 simultaneous tasks** maximum.
- [ ] No unstructured concurrency (`Task { }`, `Task.detached`) is present — or, if unavoidable, a code comment explains why.

## Principle IV — Robust Error Handling

- [ ] All errors are expressed through the unified `AppError` enum conforming to `Swift.Error`.
- [ ] `AppError` includes at minimum: `notADirectory`, `fileSizeUnavailable`, `ocrFailed`, `imageLoadFailed`, `csvWriteFailed`.
- [ ] No stringly-typed or ad-hoc error types are introduced.
- [ ] Errors propagate to the CLI layer and produce **human-readable messages on `stderr`**.
- [ ] `Result` types are used at API boundaries where explicit success/failure semantics are needed.

## Principle V — Minimal Dependencies

- [ ] The only external package dependency is `apple/swift-argument-parser`.
- [ ] OCR is performed exclusively through the native Apple **Vision** framework (`VNRecognizeTextRequest`).
- [ ] No third-party OCR, image-processing, or CSV libraries have been added.

## Principle VI — Clean Code & Swift API Design Guidelines

- [ ] All public types, methods, and properties have `///` documentation comments.
- [ ] `guard` statements are used for early exits; no deeply nested `if-let` chains.
- [ ] Names follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/): clarity at the point of use, no abbreviations, descriptive parameter labels.
- [ ] All types crossing concurrency boundaries are marked `Sendable`.

## Principle VII — No Testing Requirements (POC Scope)

- [ ] The PR is **not blocked** due to missing test coverage.
- [ ] No test targets, test plans, or testing frameworks have been added unless this principle has been formally amended.

---

## Data Model & Output Contract

- [ ] `ImageFile` struct conforms to `Sendable` and contains exactly: `fileName: String`, `ocrPayload: [(key: String, value: String, confidence: Float)]`, `averageConfidence: Float`.
- [ ] CSV output uses a **pipe (`|`) delimiter** with **UTF-8+BOM** encoding.
- [ ] CSV uses a **union-of-all-keys** column strategy: every unique key found across all `ImageFile` objects becomes a column.
- [ ] Priority columns `Nombre`, `Email`, `Teléfono` appear first (in that order); remaining columns follow alphabetically; a final `Average Confidence` column closes each row.
- [ ] The first row is a header row.
- [ ] All line breaks in field values are stripped or replaced with a single space before writing.
- [ ] Fields are **not quoted**; any pipe characters in field values are stripped before writing.

## Development Workflow & Code Style

- [ ] The project uses **Swift Package Manager** exclusively; no Xcode project files (`.xcodeproj`, `.xcworkspace`) are committed.
- [ ] `swift build` succeeds with **zero warnings** under `-strict-concurrency=complete`.
- [ ] The PR includes a brief **constitution-compliance note** confirming adherence to all seven Core Principles.

---

> **Reminder:** In any conflict between ad-hoc decisions and the constitution, the constitution prevails. If a principle needs changing, follow the amendment procedure (PR to modify the constitution, reviewed by all active contributors, version incremented per SemVer).
