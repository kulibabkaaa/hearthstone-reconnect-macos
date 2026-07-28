// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "HSReconnect",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "ProxyCore", targets: ["ProxyCore"])
  ],
  targets: [
    .target(
      name: "ProxyCore",
      path: "Shared/ProxyCore"
    ),
    .testTarget(
      name: "ProxyCoreTests",
      dependencies: ["ProxyCore"],
      path: "Tests/ProxyCoreTests"
    ),
  ]
)
