#!/bin/bash
# Pre-push check script for Constellation
# Usage: Add this as a pre-push git hook or run manually before pushing
# Checks: SwiftLint, build, and tests

set -e

# Run SwiftLint if available
if command -v swiftlint &> /dev/null; then
  echo "Running SwiftLint..."
  swiftlint
else
  echo "SwiftLint not installed. Skipping lint check."
fi

# Build the project
echo "Building project..."
xcodebuild -project Constellation.xcodeproj -scheme Constellation -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' build

# Run tests
echo "Running tests..."
xcodebuild test -project Constellation.xcodeproj -scheme Constellation -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

echo "All checks passed. Ready to push!" 