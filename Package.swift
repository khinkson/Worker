// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Worker",
    platforms: [
        .macOS(.v12)
    ],
    products: [
         .executable(name: "Worker", targets: ["Worker"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", .upToNextMajor(from: "0.5.2")),
        .package(url: "https://github.com/swift-server/async-http-client.git", .upToNextMajor(from: "1.9.0")),
        .package(url: "https://github.com/soto-project/soto.git", .upToNextMajor(from: "6.0.0-alpha.4")),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", .upToNextMajor(from: "1.3.1")),
        .package(url: "https://github.com/crossroadlabs/Regex.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/khinkson/WorkerInterface.git", .upToNextMajor(from: "0.0.1")),
        //.package(path: "../WorkerInterface")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "Worker",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "SotoSQS", package: "soto"),
                .product(name: "Regex", package: "Regex"),
                .product(name: "Backtrace", package: "swift-backtrace"),
                .product(name: "WorkerInterface", package: "WorkerInterface")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
