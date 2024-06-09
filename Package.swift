// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "barcode-server",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(
            url: "https://github.com/vapor/vapor.git", 
            from: "4.92.4"
        ),
        .package(
            // url: "https://github.com/orlandos-nl/MongoKitten.git", 
            // from: "7.2.0"
            url: "https://github.com/Peter-Schorn/MongoKitten.git",
            branch: "full-document-before-change"
        ),
        .package(
            url: "https://github.com/awslabs/aws-sdk-swift",
            from: "0.45.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "MongoKitten", package: "MongoKitten"),
                .product(name: "Meow", package: "MongoKitten"),
                .product(name: "AWSS3", package: "aws-sdk-swift"),
                .product(name: "AWSClientRuntime", package: "aws-sdk-swift"),
                .product(name: "AWSElasticBeanstalk", package: "aws-sdk-swift")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
