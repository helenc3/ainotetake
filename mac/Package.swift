// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoteTaker",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "NoteTaker", path: "Sources/NoteTaker")]
)
