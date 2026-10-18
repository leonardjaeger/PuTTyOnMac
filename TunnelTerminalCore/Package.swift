// swift-tools-version: 6.0
// TunnelTerminalCore: Sitzungsdateien, plink-Aufruf und Prüfregeln – ohne AppKit (Plan Abschnitt 3).
import PackageDescription

let package = Package(
    name: "TunnelTerminalCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TunnelTerminalCore", targets: ["TunnelTerminalCore"])
    ],
    targets: [
        .target(
            name: "TunnelTerminalCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TunnelTerminalCoreTests",
            dependencies: ["TunnelTerminalCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
