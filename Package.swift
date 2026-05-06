// swift-tools-version: 6.2
// Clipurr — macOS 26 Menu Bar Clipboard Manager

import PackageDescription

let package = Package(
    name: "Clipurr",
    platforms: [
        .macOS(.v26)  // Minimum deployment target; built for macOS 26
    ],
    products: [
        .executable(name: "Clipurr", targets: ["Clipurr"])
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0")
    ],
    targets: [
        .executableTarget(
            name: "Clipurr",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/Clipurr"
        ),
        .testTarget(
            name: "ClipurrTests",
            dependencies: [
                "Clipurr",
                "SwiftCheck"
            ],
            path: "Tests/ClipurrTests"
        )
    ]
)
