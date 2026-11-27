// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Webodrop",
    platforms: [.macOS(.v14)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "WebodropKit"),
        .executableTarget(
            name: "Webodrop",
            dependencies: ["WebodropKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "WebodropKitTests", dependencies: ["WebodropKit"]),
    ]
)
