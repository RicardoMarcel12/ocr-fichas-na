import Foundation

/// Represents a single image file discovered during a directory scan.
struct ImageFile: Sendable {
    /// Absolute path of the parent directory.
    let directory: String
    /// File name including extension.
    let filename: String
    /// File size in bytes.
    let size: Int64
    /// Processing status (default: "pending").
    let status: String
}
