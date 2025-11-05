// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParquetViewerSwift",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Parquet-View", targets: ["Parquet-View"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckdb/duckdb-swift", from: "1.1.3")
    ],
    targets: [
        .executableTarget(
            name: "Parquet-View",
            dependencies: [
                .product(name: "DuckDB", package: "duckdb-swift")
            ],
            path: "Parquet Viewer"
        )
    ]
)
