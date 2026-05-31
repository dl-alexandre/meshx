// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mob.Node",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "Mob.Node", targets: ["Mob.Node"]),
        .executable(name: "Mob.NoiseInteropCLI", targets: ["Mob.NoiseInteropCLI"]),
        .executable(name: "MobMessageObserverCLI", targets: ["MobMessageObserverCLI"])
    ],
    targets: [
        .target(name: "Mob.Node"),
        .executableTarget(
            name: "Mob.NoiseInteropCLI",
            dependencies: ["Mob.Node"]
        ),
        .executableTarget(
            name: "MobMessageObserverCLI",
            dependencies: ["Mob.Node"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/MobMessageObserverCLI/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "Mob.NodeTests",
            dependencies: ["Mob.Node"]
        )
    ]
)
