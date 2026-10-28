// swift-tools-version: 6.0
// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import PackageDescription

let package = Package(
    name: "AlphaTab",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "AlphaTab", targets: ["AlphaTabRuntime", "AlphaTab"]),
        .library(name: "AlphaTabIOS", targets: ["AlphaTabIOS"])
    ],
    targets: [
        .target(name: "AlphaTabRuntime", path: "packages/swift/Sources/AlphaTabRuntime"),
        .target(name: "AlphaTab", dependencies: ["AlphaTabRuntime"], path: "packages/swift/Sources/AlphaTab"),
        .target(name: "AlphaTabIOS", dependencies: ["AlphaTab"], path: "packages/swift/Sources/AlphaTabIOS"),
        .testTarget(
            name: "AlphaTabTests",
            dependencies: ["AlphaTab", "AlphaTabRuntime"],
            path: "packages/swift/Tests/AlphaTabTests",
            exclude: ["SKIPPED.md", "SvgGoldens"]
        )
    ],
    swiftLanguageModes: [.v6]
)
