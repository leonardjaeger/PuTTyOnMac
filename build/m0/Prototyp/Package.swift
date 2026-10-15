// swift-tools-version:6.0
// PROTOTYP M0 – Wegwerfcode, nicht das spätere App-Projekt.
import PackageDescription

let package = Package(
    name: "Prototyp",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Fest gepinnt (S7): Tag 1.99.0 = Commit 2dad6a1e516f755bed77cf9bbd09455062f54758
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.99.0")
    ],
    targets: [
        .executableTarget(
            name: "Prototyp",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            // shortcut: Swift-5-Modus, weil der Prototyp weggeworfen wird; das App-Projekt (M1) nutzt Swift 6
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
