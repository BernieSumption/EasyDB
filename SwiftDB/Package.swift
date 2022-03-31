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
        )
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftDB"
        ),
        .testTarget(
            name: "SwiftDBTests",
            dependencies: ["SwiftDB"]
        )
    ]
)
