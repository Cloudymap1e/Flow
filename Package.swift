// swift-tools-version: 5.9
#if canImport(PackageDescription)
import PackageDescription

let package = Package(
    name: "Flow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Flow", targets: ["Flow"])
    ],
    targets: [
        .executableTarget(
            name: "Flow",
            path: ".",
            exclude: [
                "Flow.xcodeproj",
                "Flow.entitlements"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
#endif
