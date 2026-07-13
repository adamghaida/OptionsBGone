// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OptionsBGone",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OptionsBGone",
            path: "Sources/OptionsBGone",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
