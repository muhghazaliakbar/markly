// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Markly",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Markly", targets: ["Markly"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "Markly",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Markly",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "MarklyTests",
            dependencies: ["Markly"],
            path: "Tests/MarklyTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
