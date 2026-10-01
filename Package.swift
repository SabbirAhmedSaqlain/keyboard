// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SecurePINKeyboard",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "SecurePINKeyboard",
            targets: ["SecurePINKeyboard"]
        )
    ],
    targets: [
        .target(
            name: "SecurePINKeyboard",
            path: "Sources/SecurePINKeyboard"
        )
    ],
    swiftLanguageVersions: [.v5]
)
