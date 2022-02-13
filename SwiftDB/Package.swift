// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SwiftDB",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "SwiftDB",
            targets: ["SwiftDB"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            providers: [
                .apt(["libsqlite3-dev"])
            ]
        ),
        .target(
            name: "SwiftDB",
            dependencies: ["CSQLite"]
        ),
        .testTarget(
            name: "SwiftDBTests",
            dependencies: ["SwiftDB"]
        ),
    ]
)
