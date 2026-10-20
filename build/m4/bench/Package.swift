// swift-tools-version: 6.0
// M4-Tempo: Parser von SwiftTerm (gleicher Checkout wie die App) im Debug- und Release-Bau, ohne Ansicht.
import PackageDescription
let package = Package(
    name: "bench", platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../../../../../Library/Caches/TunnelTerminal-Build/DerivedData/SourcePackages/checkouts/SwiftTerm")],
    targets: [.executableTarget(name: "bench", dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")])]
)
