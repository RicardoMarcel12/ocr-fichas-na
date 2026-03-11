# Feature Spec: CSV Writer

> **Status**: Draft · **Created**: 2026-03-10 · **Feature ID**: csv-writer
> **Constitution**: v1.1.0 · **Depends on**: `ocr-reader`

---

## 1 · Overview

The CSV Writer receives the collection of `ImageFile` objects produced by the OCR Reader and serializes them into a single, flat CSV file. Because forms are non-standard (each may contain different fields), the writer applies a **union-of-all-keys** column strategy — every unique key found across all processed forms becomes a column, and forms missing a given key receive an empty cell.

Three **priority columns** (`Nombre`, `Email`, `Teléfono`) are always placed first (left-to-right) regardless of discovery order. The remaining columns follow in alphabetical order. A final `Average Confidence` column closes each row. No file-name tracing column is included.

The output uses **UTF-8 with BOM** encoding and a **pipe (`|`) delimiter** to avoid ambiguity with commas, semicolons, or other punctuation that may appear in handwritten form data.

---

## 2 · User Stories

### P1 — Must Have

| ID | Story |
|----|-------|
| US-01 | As a user, I want the CSV to contain one column per unique form field so I can see all extracted data in a single flat table. |
| US-02 | As a user, I want `Nombre`, `Email`, and `Teléfono` as the first three columns so the most important contact data is immediately visible. |
| US-03 | As a user, I want forms missing a field to show an empty cell rather than being excluded, so every row has the same column count. |
| US-04 | As a user, I want an `Average Confidence` column per row so I can quickly identify low-quality extractions. |
| US-05 | As a user, I want the file written to the **parent directory** of the scanned folder by default so the output lives alongside the image folder, not inside it. |

### P2 — Should Have

| ID | Story |
|----|-------|
| US-06 | As a user, I want an optional `--output` flag to override the default path so I can control where the CSV is saved. |
| US-07 | As a user, I want the CSV encoded as UTF-8 with BOM so Microsoft Excel correctly renders Spanish characters (ñ, á, é, etc.). |
| US-08 | As a user, I want the pipe character (`\|`) as the delimiter so there is no confusion with commas or other punctuation inside form values. |

### P3 — Nice to Have

| ID | Story |
|----|-------|
| US-09 | As a user, I want a summary printed to stdout after export showing the row count and output file path. |

---

## 3 · Functional Requirements

### 3.1 · Column Discovery & Ordering

| ID | Requirement | Constitution Ref |
|----|-------------|-----------------|
| FR-001 | The writer **SHALL** iterate all `ImageFile` objects and collect every unique key from each `ocrPayload` into a deduplicated set. | — |
| FR-002 | The writer **SHALL** place three priority columns first, in this fixed order: `Nombre`, `Email`, `Teléfono`. If a priority key is absent from the entire dataset, its column **SHALL** still appear with empty cells in every row. | — |
| FR-003 | All remaining columns **SHALL** be sorted alphabetically (locale-insensitive, Unicode ordinal) and appended after the priority columns. | — |
| FR-004 | The final column **SHALL** always be `Average Confidence`. | — |

### 3.2 · Row Serialization

| ID | Requirement | Constitution Ref |
|----|-------------|-----------------|
| FR-005 | Each `ImageFile` object **SHALL** produce exactly one row. | — |
| FR-006 | For each column, the writer **SHALL** look up the matching value from the `ImageFile.ocrPayload` by key. If no matching entry exists for that form, the cell **SHALL** be empty. | — |
| FR-007 | The `Average Confidence` cell **SHALL** contain the `ImageFile.averageConfidence` value formatted as a decimal with **2 decimal places** (e.g., `0.87`). | — |
| FR-008 | Field values **SHALL** be sanitized: newline characters (`\n`, `\r`, `\r\n`) replaced with a single space. | Principle VI |
| FR-009 | If a field value contains the pipe delimiter (`\|`), it **SHALL** be stripped (removed) from the value since pipe is guaranteed to never be intentional content. | — |

### 3.3 · File Output

| ID | Requirement | Constitution Ref |
|----|-------------|-----------------|
| FR-010 | The writer **SHALL** conform to the `CSVExporting` protocol defined by the Constitution (Principle II). | Principle II |
| FR-011 | The default output path **SHALL** be computed as: `<scannedDirectory>/../ocr_results.csv` — i.e., the **parent directory** of the folder containing the images. The path **SHALL** be resolved to an absolute canonical path. | — |
| FR-012 | When the user provides the `--output <path>` flag, the writer **SHALL** use that path verbatim (after tilde and symlink resolution). | — |
| FR-013 | If the destination directory does not exist, the writer **SHALL** throw `AppError.csvWriteFailed` with a descriptive message; it **SHALL NOT** create intermediate directories. | Principle IV |
| FR-014 | The file **SHALL** be encoded as **UTF-8 with BOM** (byte sequence `EF BB BF` prepended). | — |
| FR-015 | The first line **SHALL** be a header row with column names separated by the pipe delimiter. | — |
| FR-016 | All rows (header + data) **SHALL** be terminated with `\n` (Unix line ending). | — |

### 3.4 · Delimiter & Quoting

| ID | Requirement | Constitution Ref |
|----|-------------|-----------------|
| FR-017 | The field delimiter **SHALL** be the pipe character (`\|`, U+007C). | — |
| FR-018 | Fields **SHALL NOT** be quoted. Since pipe is guaranteed to never appear in intentional form content (FR-009 strips it), quoting is unnecessary. | — |

### 3.5 · Protocol & Type Conformance

| ID | Requirement | Constitution Ref |
|----|-------------|-----------------|
| FR-019 | The `CSVExporter` struct/class **SHALL** conform to the `CSVExporting` protocol with at minimum: `func export(results: [ImageFile], to outputPath: URL) throws`. | Principle II |
| FR-020 | `CSVExporter` **SHALL** be `Sendable`. | Principle I |
| FR-021 | Errors **SHALL** use `AppError.csvWriteFailed` with contextual messages (e.g., "Cannot write to /path: directory does not exist"). | Principle IV |

---

## 4 · Non-Functional Requirements

| ID | Requirement | Constitution Ref |
|----|-------------|-----------------|
| NFR-01 | The writer **SHALL** compile with zero warnings under Swift 6 strict concurrency checking. | Principle I |
| NFR-02 | No third-party CSV libraries **SHALL** be used; the writer is implemented with Foundation only. | Principle V |
| NFR-03 | No unit tests, integration tests, or e2e tests are required. | Principle VII |
| NFR-04 | Code **SHALL** use `///` doc comments on all public API surfaces. | Principle VI |

---

## 5 · Data Flow

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│ OCR Reader   │────▶│  CSV Writer   │────▶│  .csv file   │
│ [ImageFile]  │     │  CSVExporter  │     │  UTF-8 + BOM │
└─────────────┘     └──────────────┘     └──────────────┘
                            │
                    ┌───────┴────────┐
                    │ Column Strategy│
                    │                │
                    │ 1. Nombre      │
                    │ 2. Email       │
                    │ 3. Teléfono    │
                    │ 4. [A-Z rest]  │
                    │ 5. Avg Conf.   │
                    └────────────────┘
```

---

## 6 · Example Output

Given two processed forms:

**Form A** fields: `Nombre: Ana López`, `Email: ana@mail.com`, `Teléfono: 7777-1234`, `Profesión: Ingeniera`
**Form B** fields: `Nombre: Carlos Ruiz`, `Dirección: Col. Escalón`, `Teléfono: 7777-5678`

The CSV output would be:

```
Nombre|Email|Teléfono|Dirección|Profesión|Average Confidence
Ana López|ana@mail.com|7777-1234||Ingeniera|0.91
Carlos Ruiz||7777-5678|Col. Escalón||0.85
```

*(UTF-8 BOM prepended, no quoting, empty cells for missing fields)*

---

## 7 · CLI Integration (cross-reference: `cli` spec)

| Aspect | Detail |
|--------|--------|
| Flag | `--output <path>` (optional) |
| Short flag | `-o <path>` |
| Default | `<input_directory>/../ocr_results.csv` |
| Validation | Destination directory must exist; file is overwritten if it already exists |

---

## 8 · Success Criteria

| # | Criterion |
|---|-----------|
| SC-01 | Given 2+ non-standard forms, the CSV contains a superset of all unique keys as columns. |
| SC-02 | `Nombre`, `Email`, `Teléfono` are always the first three columns regardless of form content. |
| SC-03 | Missing fields produce empty cells (two consecutive pipes `\|\|`). |
| SC-04 | The `Average Confidence` column is the last column with 2-decimal formatting. |
| SC-05 | The file opens correctly in Excel on macOS with Spanish characters rendered properly. |
| SC-06 | `--output /custom/path.csv` writes to the specified path. |
| SC-07 | Omitting `--output` writes to the parent directory of the scanned folder. |
| SC-08 | The project compiles with zero warnings under `swift build`. |

---

## 9 · Open Questions

*None — all clarifications resolved during specification.*
