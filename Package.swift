// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ocr-fichas-na",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "ocr-fichas-na",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/OcrFichasNa"
        ),
    ]
)
