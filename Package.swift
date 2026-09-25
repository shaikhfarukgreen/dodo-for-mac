// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DodoMac",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "DodoMac",
            path: "Sources/DodoMac",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
            ]
        )
    ]
)
