// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Clipsmith",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Clipsmith",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ClipsmithTests",
            dependencies: ["Clipsmith"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
