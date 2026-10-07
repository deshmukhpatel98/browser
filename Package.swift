// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Browser",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        // Shared by every Apple platform: tabs, page reading, the agent loop.
        .target(name: "BrowserCore"),
        .executableTarget(name: "BrowserMac", dependencies: ["BrowserCore"]),
    ]
)
