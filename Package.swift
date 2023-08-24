// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Cuckoo",
    products: [
        .library(
            name: "Cuckoo",
            targets: ["Cuckoo"]
        ),
    ],
    targets: [
        .target(
            name: "Cuckoo",
            dependencies: [],
            path: "Source",
            linkerSettings: [.linkedFramework("XCTest")]
        ),
        .testTarget(
            name: "CuckooTests",
            dependencies: ["Cuckoo"],
            path: "Tests"
        ),
    ]
)
