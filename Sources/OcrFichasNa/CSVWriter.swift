import Foundation

/// Writes a list of `ImageFile` values to a CSV file.
struct CSVWriter: Sendable {
    /// The CSV header row.
    static let header = "directory,filename,size,status"

    /// Serialises `images` into a CSV file at `url`.
    ///
    /// - Parameters:
    ///   - images: The image records to write.
    ///   - url: Destination file URL.
    /// - Throws: Any error produced by `String.write(to:atomically:encoding:)`.
    func write(images: [ImageFile], to url: URL) throws {
        var lines = [Self.header]
        for image in images {
            let row = [
                csvEscape(image.directory),
                csvEscape(image.filename),
                "\(image.size)",
                csvEscape(image.status),
            ].joined(separator: ",")
            lines.append(row)
        }
        let csv = lines.joined(separator: "\n") + "\n"
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Private helpers

    /// Wraps a field in double-quotes when it contains a comma, double-quote,
    /// or newline, escaping any embedded double-quotes by doubling them.
    private func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
