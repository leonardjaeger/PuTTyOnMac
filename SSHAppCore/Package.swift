// swift-tools-version: 6.0
// SSHAppCore: Sitzungsdateien, plink-Aufruf und Prüfregeln – ohne AppKit (Plan Abschnitt 3).
import PackageDescription

let package = Package(
    name: "SSHAppCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SSHAppCore", targets: ["SSHAppCore"])
    ],
    targets: [
        .target(
            name: "SSHAppCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SSHAppCoreTests",
            dependencies: ["SSHAppCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
