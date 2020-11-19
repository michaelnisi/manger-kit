// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MangerKit",
  platforms: [
    .iOS(.v13), .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "MangerKit",
      targets: ["MangerKit"]),
  ],
  dependencies: [
    .package(name: "Patron", url: "/Users/michael/swift/patron", .branch("pkg"))
  ],
  targets: [
    .target(
      name: "MangerKit",
      dependencies: ["Patron"]),
    .testTarget(
      name: "MangerKitTests",
      dependencies: ["MangerKit"]),
  ]
)

