// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "TwistSpaces",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "TwistSpaces", targets: ["TwistSpaces"])
    ],
    targets: [
        .executableTarget(
            name: "TwistSpaces",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TwistSpacesTests",
            dependencies: ["TwistSpaces"]
        )
    ]
)
