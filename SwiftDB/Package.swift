// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SwiftDB",
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
            name: "SQLite3",
            providers: [
                .apt(["libsqlite3-dev"])
            ]
        ),
        .target(
            name: "SwiftDB",
            dependencies: ["SQLite3"]
        ),
        .testTarget(
            name: "SwiftDBTests",
            dependencies: ["SwiftDB"]
        ),
    ]
)
