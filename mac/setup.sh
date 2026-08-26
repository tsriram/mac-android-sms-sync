#!/bin/bash
# Setup script for SMSync Mac app

set -e

echo "=== SMSync Mac App Setup ==="
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed"
    exit 1
fi

echo "Xcode found: $(xcodebuild -version | head -1)"

# Create Xcode project using swift package
echo ""
echo "Creating Xcode project..."

cd "$(dirname "$0")"

# Open Package.swift in Xcode
echo "Opening Package.swift in Xcode..."
open Package.swift

echo ""
echo "=== Setup Complete ==="
echo ""
echo "In Xcode:"
echo "1. Select 'SMSync' scheme in the toolbar"
echo "2. Choose 'My Mac' as the destination"
echo "3. Press Cmd+R to build and run"
echo ""
echo "Note: The first build may take a while as Swift resolves dependencies."
