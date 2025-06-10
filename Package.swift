// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LegalCitationChecker",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Core citation checking functionality
        .library(
            name: "LegalCitationChecker",
            targets: ["LegalCitationChecker"]
        ),
        // UI components for citation highlighting and validation display
        .library(
            name: "LegalCitationCheckerUI",
            targets: ["LegalCitationCheckerUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vpeschenkov/SecureDefaults.git", from: "1.2.2")
    ],
    targets: [
        // Core citation checking logic
        .target(
            name: "LegalCitationChecker",
            dependencies: ["SecureDefaults"],
            path: "Sources/LegalCitationChecker"
        ),
        // UI components that depend on the core library
        .target(
            name: "LegalCitationCheckerUI",
            dependencies: ["LegalCitationChecker"],
            path: "Sources/LegalCitationCheckerUI"
        ),
        // Tests for the core functionality
        .testTarget(
            name: "LegalCitationCheckerTests",
            dependencies: ["LegalCitationChecker"]
        ),
    ]
) 