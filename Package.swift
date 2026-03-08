// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MyNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MyNotes", targets: ["MyNotes"])
    ],
    dependencies: [
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.1.2")
    ],
    targets: [
        .executableTarget(
            name: "MyNotes",
            dependencies: [
                .product(name: "Highlightr", package: "Highlightr")
            ],
            path: "MyNotes",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
