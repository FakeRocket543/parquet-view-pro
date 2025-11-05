#!/bin/bash
# ?? Parquet View Swift - ????

echo "?? Building Parquet View..."
cd ~/Desktop/ParquetViewerSwift
swift build

if [ $? -eq 0 ]; then
    echo "? Build successful!"
    echo "?? Launching Parquet View..."
    
    # Kill any existing instances
    killall Parquet-View 2>/dev/null
    
    # Run the app
    .build/debug/Parquet-View &
    
    echo "? App launched!"
    echo ""
    echo "?? ?????"
    echo "1. ???????????"
    echo "2. ?? 'Open File' ??"
    echo "3. ?? Parquet ???"
    echo "   /Users/fl/Python/Parquet_View/sample_data.parquet"
    echo ""
    echo "?? ????????????? Dock ?? Cmd+Tab ??"
else
    echo "? Build failed!"
    exit 1
fi
