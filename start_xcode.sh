#!/bin/bash
# Quick start script for Parquet Viewer Swift development

set -e

PROJECT_DIR="/Users/fl/Desktop/ParquetViewerSwift"
RUST_PROJECT="/Users/fl/Python/Parquet_View"

echo "?? Parquet Viewer - Swift Migration"
echo "======================================"
echo ""

# Check prerequisites
echo "?? Checking prerequisites..."
echo ""

if ! command -v xcodebuild &> /dev/null; then
    echo "? Xcode not found. Please install Xcode from App Store."
    exit 1
fi
echo "? Xcode found: $(xcodebuild -version | head -1)"

if ! command -v swift &> /dev/null; then
    echo "? Swift not found"
    exit 1
fi
echo "? Swift found: $(swift --version | head -1)"

echo ""
echo "======================================"
echo "?? Project Status"
echo "======================================"
echo ""

# Check files
echo "Swift source files:"
ls -1 "$PROJECT_DIR/Parquet Viewer/"*.swift 2>/dev/null | while read file; do
    lines=$(wc -l < "$file" | tr -d ' ')
    echo "  ? $(basename "$file") ($lines lines)"
done

echo ""
echo "Configuration files:"
[ -f "$PROJECT_DIR/Parquet Viewer/Info.plist" ] && echo "  ? Info.plist" || echo "  ? Info.plist missing"
[ -f "$PROJECT_DIR/Parquet Viewer/Package.swift" ] && echo "  ? Package.swift" || echo "  ? Package.swift missing"

echo ""
echo "Documentation:"
[ -f "$PROJECT_DIR/README.md" ] && echo "  ? README.md" || echo "  ? README.md missing"
[ -f "$PROJECT_DIR/BUILD_INSTRUCTIONS.md" ] && echo "  ? BUILD_INSTRUCTIONS.md" || echo "  ? BUILD_INSTRUCTIONS.md missing"
[ -f "$PROJECT_DIR/MIGRATION_STATUS.md" ] && echo "  ? MIGRATION_STATUS.md" || echo "  ? MIGRATION_STATUS.md missing"

echo ""
echo "Test data:"
[ -f "$RUST_PROJECT/sample_data.parquet" ] && echo "  ? sample_data.parquet" || echo "  ??  sample_data.parquet not found"

echo ""
echo "======================================"
echo "?? Next Steps"
echo "======================================"
echo ""
echo "1. Create Xcode project:"
echo "   - Launch Xcode"
echo "   - File ? New ? Project"
echo "   - Choose: macOS ? App"
echo "   - Product Name: Parquet Viewer"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Save to: $PROJECT_DIR"
echo ""
echo "2. Add DuckDB package:"
echo "   - In Xcode project settings"
echo "   - Package Dependencies ? +"
echo "   - URL: https://github.com/duckdb/duckdb-swift"
echo ""
echo "3. Copy source files to Xcode:"
echo "   - Files are already in: $PROJECT_DIR/Parquet Viewer/"
echo "   - Replace generated ContentView.swift"
echo "   - Add other .swift files to project"
echo ""
echo "4. Build and test (SM-2 validation):"
echo "   - Press Cmd+B to build"
echo "   - Press Cmd+R to run"
echo "   - Open: $RUST_PROJECT/sample_data.parquet"
echo ""
echo "======================================"
echo ""

read -p "Open Xcode now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "?? Launching Xcode..."
    open -a Xcode
    echo ""
    echo "?? Follow the steps above to create your project"
    echo "?? Read BUILD_INSTRUCTIONS.md for detailed guide"
    echo ""
else
    echo ""
    echo "?? When ready, read: $PROJECT_DIR/BUILD_INSTRUCTIONS.md"
    echo ""
fi

echo "======================================"
echo "?? Useful Commands"
echo "======================================"
echo ""
echo "# Open project folder in Finder:"
echo "open $PROJECT_DIR"
echo ""
echo "# View documentation:"
echo "cat $PROJECT_DIR/BUILD_INSTRUCTIONS.md | less"
echo ""
echo "# Copy test file to Desktop for quick testing:"
echo "cp $RUST_PROJECT/sample_data.parquet ~/Desktop/test.parquet"
echo ""
echo "# Check Swift code stats:"
echo "find $PROJECT_DIR -name '*.swift' -exec wc -l {} + | tail -1"
echo ""
echo "======================================"
echo "? Setup complete! Ready to build."
echo "======================================"
