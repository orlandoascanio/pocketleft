// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pocket",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Pocket", targets: ["Pocket"])],
    dependencies: [
        // Crash reports (CrashReporting.swift). Compiled from source so `swift build` links it statically.
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.36.0"),
    ],
    targets: [
        // Pure money logic: no UI, no storage. Everything here is unit-tested.
        .target(name: "PocketCore"),
        .executableTarget(name: "Pocket", dependencies: [
            "PocketCore",
            .product(name: "SentrySPM", package: "sentry-cocoa"),
        ]),
        .testTarget(name: "PocketCoreTests", dependencies: ["PocketCore"]),
        .testTarget(name: "PocketAppTests", dependencies: ["Pocket"]),
    ]
)
