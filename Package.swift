// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZipMaster",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ZipMaster",
            path: "Sources/ZipMaster"
        ),
        .testTarget(
            name: "ZipMasterTests",
            dependencies: ["ZipMaster"],
            path: "Tests/ZipMasterTests"
        ),
    ]
)
