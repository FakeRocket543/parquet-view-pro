// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParquetViewerSwift",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Parquet-View", targets: ["ParquetViewMain"]),
        .library(name: "ParquetViewLib", targets: ["ParquetViewLib"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckdb/duckdb-swift", from: "1.1.3")
    ],
    targets: [
        .target(
            name: "ParquetViewLib",
            dependencies: [
                .product(name: "DuckDB", package: "duckdb-swift")
            ],
            path: "Parquet Viewer",
            exclude: [
                "Assets.xcassets",
                "Preview Content",
                "Info.plist"
            ]
        ),
        .executableTarget(
            name: "ParquetViewMain",
            dependencies: ["ParquetViewLib"],
            path: "Sources/ParquetViewMain"
        ),
        .testTarget(
            name: "ParquetViewerTests",
            dependencies: ["ParquetViewLib"],
            path: "Parquet ViewerTests"
        )
    ]
)
