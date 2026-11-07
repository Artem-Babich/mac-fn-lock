// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "fn-lock",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "FnLockCore"),
        .executableTarget(name: "fnlock", dependencies: ["FnLockCore"]),
        .testTarget(name: "FnLockCoreTests", dependencies: ["FnLockCore"]),
    ],
    swiftLanguageModes: [.v5]
)
