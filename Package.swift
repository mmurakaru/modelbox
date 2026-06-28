// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Modelbox",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Modelbox", targets: ["Modelbox"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Modelbox",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Modelbox",
            exclude: ["Resources/Info.plist.template", "Resources/AppIcon.svg"]
        ),
        .testTarget(
            name: "ModelboxTests",
            dependencies: ["Modelbox"],
            path: "Tests/ModelboxTests"
        ),
    ]
)
