# Code Review Checklist — ocr-fichas-na Constitution Compliance

When reviewing a pull request for this project, verify each of the following items. The PR **MUST NOT** be merged until every applicable item is confirmed.

---

## Principle I — Swift 6 Strict Concurrency

- [ ] Code compiles under **Swift 6** with Complete Concurrency Checking enabled.
- [ ] Deployment target remains **macOS 13+**.
- [ ] Every type that crosses a concurrency boundary conforms to `Sendable`.
- [ ] No `@unchecked Sendable` is used without an explicit, documented justification in the PR description.

## Principle II — Protocol-Oriented Architecture

- [ ] Module boundaries (filesystem access, OCR, CSV exporting) are clearly separated; currently implemented via concrete types `ImageScanner` and `CSVWriter`. If protocol abstractions (`FileSystemManaging`, `OCRProcessing`, `CSVExporting`) are introduced, they MUST be honored.
- [ ] The CLI entry point uses `ParsableCommand` from Swift Argument Parser (or `AsyncParsableCommand` if the project is migrated to async commands).
- [ ] Object-Oriented and Protocol-Oriented patterns are the primary paradigms; free functions are used only for trivial utilities.
- [ ] New components have a single, clear responsibility and define a protocol abstraction when substitutability or testability is required.

## Principle III — Structured Concurrency & Performance

- [ ] All concurrent work uses Swift Structured Concurrency (`async`/`await`).
- [ ] Parallel image processing uses `TaskGroup`.
- [ ] Concurrent OCR tasks are throttled to **4–8 simultaneous tasks** maximum.
- [ ] No unstructured concurrency (`Task { }`, `Task.detached`) is present — or, if unavoidable, a code comment explains why.

## Principle IV — Robust Error Handling

- [ ] Errors use the project's established error model (e.g. `ScanError` and standard Swift/Foundation errors) rather than introducing unused or fictional types.
- [ ] All custom error types conform to `Swift.Error` and are well-defined (e.g. `enum`/`struct`), with cases that clearly describe the failure conditions.
- [ ] No stringly-typed or ad-hoc error types are introduced.
- [ ] Errors propagate to the CLI layer and produce **human-readable messages on `stderr`**.
- [ ] `Result` types are used at API boundaries where explicit success/failure semantics are needed.

## Principle V — Minimal Dependencies

- [ ] The only external package dependency is `apple/swift-argument-parser`.
- [ ] When OCR functionality is implemented, it MUST be performed exclusively through the native Apple **Vision** framework (`VNRecognizeTextRequest`).
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

- [ ] `ImageFile` struct conforms to `Sendable` and contains exactly the properties: `directory`, `filename`, `size`, and `status`.
- [ ] CSV output contains exactly four columns in order: **Directory**, **File Name**, **Size**, **Status**.
- [ ] The first row is a header row matching these four column names.
- [ ] No CSV field contains raw newline characters; any internal line breaks are normalized before writing.
- [ ] Fields containing commas or quotes are properly escaped per **RFC 4180**.

## Development Workflow & Code Style

- [ ] The project uses **Swift Package Manager** exclusively; no Xcode project files (`.xcodeproj`, `.xcworkspace`) are committed.
- [ ] `swift build -Xswiftc -strict-concurrency=complete` succeeds with **zero warnings**.
- [ ] The PR includes a brief **constitution-compliance note** confirming adherence to all seven Core Principles.

---

> **Reminder:** These checklist items reflect the project's current architecture and intended direction. If a requirement needs changing, open a PR updating this checklist with justification, reviewed by all active contributors.
