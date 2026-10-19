// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TodoOrganizer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TodoOrganizer", path: "Sources")
    ]
)
