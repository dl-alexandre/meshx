// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshxMobile",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "MeshxMobile", targets: ["MeshxMobile"]),
        .executable(name: "MeshxNoiseInteropCLI", targets: ["MeshxNoiseInteropCLI"]),
        .executable(name: "MeshxMessageObserverCLI", targets: ["MeshxMessageObserverCLI"])
    ],
    targets: [
        .target(name: "MeshxMobile"),
        .executableTarget(
            name: "MeshxNoiseInteropCLI",
            dependencies: ["MeshxMobile"]
        ),
        .executableTarget(
            name: "MeshxMessageObserverCLI",
            dependencies: ["MeshxMobile"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/MeshxMessageObserverCLI/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "MeshxMobileTests",
            dependencies: ["MeshxMobile"]
        )
    ]
)
