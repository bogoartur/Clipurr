// swift-tools-version: 6.2
// CopyCat — macOS 26 Menu Bar Clipboard Manager

import PackageDescription

let package = Package(
    name: "CopyCat",
    platforms: [
        .macOS(.v26)  // Minimum deployment target; built for macOS 26
    ],
    products: [
        .executable(name: "CopyCat", targets: ["CopyCat"])
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "CopyCat",
            path: "Sources/CopyCat"
        ),
        .testTarget(
            name: "CopyCatTests",
            dependencies: [
                "CopyCat",
                "SwiftCheck"
            ],
            path: "Tests/CopyCatTests"
        )
    ]
)
