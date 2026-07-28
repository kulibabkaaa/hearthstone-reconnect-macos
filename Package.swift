// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "HSReconnect",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "ProxyCore", targets: ["ProxyCore"]),
    .library(name: "AppCore", targets: ["AppCore"]),
  ],
  targets: [
    .target(
      name: "ProxyCore",
      path: "Shared/ProxyCore"
    ),
    .target(
      name: "AppCore",
      path: "Shared/AppCore"
    ),
    .testTarget(
      name: "ProxyCoreTests",
      dependencies: ["ProxyCore"],
      path: "Tests/ProxyCoreTests"
    ),
    .testTarget(
      name: "AppCoreTests",
      dependencies: ["AppCore"],
      path: "Tests/AppCoreTests"
    ),
  ]
)
