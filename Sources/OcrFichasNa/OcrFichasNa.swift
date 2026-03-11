import ArgumentParser
import Foundation

/// `ocr-fichas-na` – scans a directory for image files and writes a CSV list.
///
/// Usage examples:
/// ```
/// ocr-fichas-na /path/to/images
/// ocr-fichas-na --here
/// ```
@main
struct OcrFichasNa: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ocr-fichas-na",
        abstract: "Scans a directory for image files and outputs a CSV list.",
        discussion: """
            Produces a CSV file named 'image-list.csv' inside the scanned
            directory. Each row contains: directory, filename, size (bytes),
            and status (initially 'pending').
            """
    )

    // MARK: - Arguments & flags

    @Argument(help: "Path to the directory that contains the image files.")
    var directory: String?

    @Flag(name: .long, help: "Scan the current working directory.")
    var here: Bool = false

    // MARK: - Validation

    mutating func validate() throws {
        if here && directory != nil {
            throw ValidationError(
                "Provide either a directory argument or --here, not both."
            )
        }
        if !here && directory == nil {
            throw ValidationError(
                "Provide a directory path or pass --here to scan the current directory."
            )
        }
    }

    // MARK: - Run

    mutating func run() throws {
        let targetURL: URL = here
            ? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            : URL(fileURLWithPath: directory!)  // validated above

        let scanner = ImageScanner()
        let images = try scanner.scan(directory: targetURL)

        let csvURL = targetURL.appendingPathComponent("image-list.csv")
        let writer = CSVWriter()
        try writer.write(images: images, to: csvURL)

        print("Scanned : \(targetURL.path)")
        print("Images  : \(images.count)")
        print("CSV     : \(csvURL.path)")
    }
}
