// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flow",
    platforms: [
        .macOS(.v12)
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
                "Flow.entitlements",
                "Info.plist" // Assuming there might be one, or just to be safe
            ],
            resources: [
                .process("Assets.xcassets") // If it exists
            ]
        )
    ]
)
