#!/bin/bash
set -e

echo "🚀 Creating minimal Xcode project..."

PROJECT_DIR="/Users/fl/Desktop/ParquetViewerSwift"
cd "$PROJECT_DIR"

# Create Xcode project directory if it doesn't exist
mkdir -p "Parquet Viewer.xcodeproj"

# Create minimal project.pbxproj
cat > "Parquet Viewer.xcodeproj/project.pbxproj" << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
		5D1234567890ABCD /* ParquetViewerApp.swift */ = {
			isa = PBXFileReference;
			lastKnownFileType = sourcecode.swift;
			path = ParquetViewerApp.swift;
			sourceTree = "<group>";
		};
		5D1234567890ABCE /* DuckDBManager.swift */ = {
			isa = PBXFileReference;
			lastKnownFileType = sourcecode.swift;
			path = DuckDBManager.swift;
			sourceTree = "<group>";
		};
		5D1234567890ABCF /* ContentView.swift */ = {
			isa = PBXFileReference;
			lastKnownFileType = sourcecode.swift;
			path = ContentView.swift;
			sourceTree = "<group>";
		};
		5D1234567890ABD0 /* DataTableView.swift */ = {
			isa = PBXFileReference;
			lastKnownFileType = sourcecode.swift;
			path = DataTableView.swift;
			sourceTree = "<group>";
		};
		5D1234567890ABD1 /* SettingsView.swift */ = {
			isa = PBXFileReference;
			lastKnownFileType = sourcecode.swift;
			path = SettingsView.swift;
			sourceTree = "<group>";
		};
		5D1234567890ABD2 /* Info.plist */ = {
			isa = PBXFileReference;
			lastKnownFileType = text.plist.xml;
			path = Info.plist;
			sourceTree = "<group>";
		};
		5D1234567890ABD3 /* Parquet Viewer.app */ = {
			isa = PBXFileReference;
			explicitFileType = wrapper.application;
			includeInIndex = 0;
			path = "Parquet Viewer.app";
			sourceTree = BUILT_PRODUCTS_DIR;
		};
	};
	rootObject = 5D1234567890ABD4 /* Project object */;
}
EOF

echo "✅ Minimal Xcode project created"
echo ""
echo "⚠️  This is a minimal project file."
echo "   You still need to open it in Xcode and configure:"
echo "   1. Add DuckDB-Swift package"
echo "   2. Configure build settings"
echo "   3. Add signing certificate"
echo ""
echo "Opening Xcode..."
open "Parquet Viewer.xcodeproj"

