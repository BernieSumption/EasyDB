// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "EasyDB",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "EasyDB",
            targets: ["EasyDB"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "EasyDB",
            plugins: ["SwiftLintXcode"]
        ),
        .testTarget(
            name: "EasyDBTests",
            dependencies: ["EasyDB"],
            plugins: ["SwiftLintXcode"]
        ),

        // 1. Specify where to download the compiled swiftlint tool from.
        .binaryTarget(
            name: "SwiftLintBinary",
            url: "https://github.com/juozasvalancius/SwiftLint/releases/download/spm-accommodation/SwiftLintBinary-macos.artifactbundle.zip",
            checksum: "cdc36c26225fba80efc3ac2e67c2e3c3f54937145869ea5dbcaa234e57fc3724"
        ),
        // 2. Define the SPM plugin.
        .plugin(
            name: "SwiftLintXcode",
            capability: .buildTool(),
            dependencies: ["SwiftLintBinary"]
        )
    ]
)
