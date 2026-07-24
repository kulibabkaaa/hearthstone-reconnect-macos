// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "HSReconnect",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "HSReconnect", targets: ["HSReconnect"]),
    .executable(name: "HSReconnectWatcher", targets: ["HSReconnectWatcher"]),
  ],
  targets: [
    .executableTarget(name: "HSReconnect"),
    .executableTarget(name: "HSReconnectWatcher"),
    .testTarget(
      name: "HSReconnectTests",
      dependencies: ["HSReconnect"]
    ),
  ]
)
