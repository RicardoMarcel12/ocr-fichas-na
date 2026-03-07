import Foundation

/// Errors that can occur while scanning a directory.
enum ScanError: Error, CustomStringConvertible {
    case notADirectory(String)
    case fileSizeUnavailable(String)

    var description: String {
        switch self {
        case .notADirectory(let path):
            return "'\(path)' is not a directory."
        case .fileSizeUnavailable(let path):
            return "Could not determine file size for '\(path)'."
        }
    }
}

/// Scans a directory (non-recursively) for image files.
struct ImageScanner: Sendable {
    /// Recognised image file extensions (lowercased).
    static let imageExtensions: Set<String> = [
        "bmp", "gif", "heic", "heif",
        "jpeg", "jpg", "png", "tif", "tiff", "webp",
    ]

    /// Returns an array of `ImageFile` values for every image found in
    /// `directory`, sorted by filename.
    ///
    /// - Parameter directory: The directory URL to scan.
    /// - Throws: `ScanError.notADirectory` when the URL does not point to
    ///   an existing directory, or any `FileManager` / `URLResourceValues` error.
    func scan(directory: URL) throws -> [ImageFile] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanError.notADirectory(directory.path)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var images: [ImageFile] = []
        for url in contents {
            guard Self.imageExtensions.contains(url.pathExtension.lowercased()) else { continue }

            let resources = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])

            // Skip directories and symlinks that happen to have an image extension.
            guard resources.isRegularFile == true else { continue }

            guard let fileSize = resources.fileSize else {
                throw ScanError.fileSizeUnavailable(url.path)
            }

            images.append(ImageFile(
                directory: url.deletingLastPathComponent().path,
                filename: url.lastPathComponent,
                size: Int64(fileSize),
                status: "pending"
            ))
        }

        return images.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
    }
}
