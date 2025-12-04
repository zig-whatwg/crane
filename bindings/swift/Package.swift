// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhatWG",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
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
