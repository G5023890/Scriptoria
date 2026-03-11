// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MyNotes",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "MyNotes", targets: ["MyNotes"])
    ],
    dependencies: [
        .package(path: "Vendor/Highlightr")
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
