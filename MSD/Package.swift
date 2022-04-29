// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MSD",
    platforms: [
        .macOS(.v11),
        .iOS(.v13)
    ],
    products: [
        // Exposes MSD ECS with Metal Renderer 
        .library(
            name: "MSD",
            targets: ["MSD", "MetalRender"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MSD",
            dependencies: []),
        
        // Adds rendering support on top of ECS
        .target(
            name: "MetalRender",
            dependencies: ["MSD", "MetalRenderShaders"]
        ),
        
        // I think this is required b/c I need the ShaderTypes file
        .target(name: "MetalRenderShaders",
                resources: [.process("Shaders.metal")]),
        
        .testTarget(
            name: "MSDTests",
            dependencies: ["MSD"]),
    ]
)
