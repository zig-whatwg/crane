// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhatWG",
    platforms: [
        .iOS("17.0"),
        .macOS("14.0"),
        .tvOS("17.0"),
        .watchOS("10.0")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WhatWG",
            targets: ["WhatWG"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // System library target for the Zig-compiled C library
        .systemLibrary(
            name: "CWhatWG",
            path: "Sources/CWhatWG"
        ),
        // Main library target
        .target(
            name: "WhatWG",
            dependencies: ["CWhatWG"],
            path: "Sources/WhatWG"
        ),
        // Test target
        .testTarget(
            name: "WhatWGTests",
            dependencies: ["WhatWG"],
            path: "Tests/WhatWGTests"
        ),
    ]
)
