// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EscaletaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EscaletaKit", targets: ["EscaletaKit"]),
    ],
    targets: [
        .target(name: "EscaletaKit"),
        .testTarget(name: "EscaletaKitTests", dependencies: ["EscaletaKit"]),
    ]
)
