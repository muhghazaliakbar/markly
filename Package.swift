// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Markly",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Markly", targets: ["Markly"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Markly",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/Markly"
        ),
        .testTarget(
            name: "MarklyTests",
            dependencies: ["Markly"],
            path: "Tests/MarklyTests"
        )
    ]
)
