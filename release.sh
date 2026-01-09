#!/bin/bash

# Configuration
SCHEME="OpenMacCleanerApp"
PROJECT="OpenMacCleanerApp/OpenMacCleanerApp.xcodeproj"
ARCHIVE_PATH=".build/OpenMacCleaner.xcarchive"
EXPORT_PATH=".build/Export"
ZIP_NAME="OpenMacCleaner.zip"
VERSION="v1.0.0"

# Check dependencies
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Please install it: brew install gh"
    exit 1
fi

echo "🚀 Starting Release Build for $VERSION..."

# 1. Clean and Archive
echo "📦 Archiving..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath ".build/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO || exit 1

# 2. Export (Simple copy for unsigned/ad-hoc)
echo "📂 Exporting .app..."
mkdir -p "$EXPORT_PATH"
# Copy .app from archive to export path
cp -r "$ARCHIVE_PATH/Products/Applications/OpenMacCleaner.app" "$EXPORT_PATH/"

# 3. Zip
echo "🤐 Zipping..."
cd "$EXPORT_PATH"
zip -r "../../$ZIP_NAME" "OpenMacCleaner.app"
cd -

# 4. Create GitHub Release
echo "⬆️  Creating GitHub Release..."
if gh release create "$VERSION" "$ZIP_NAME" --title "$VERSION" --generate-notes; then
    echo "✅ Release $VERSION created successfully!"
else
    echo "⚠️  Failed to create release. Using existing release?"
    # Retry upload only if needed
    gh release upload "$VERSION" "$ZIP_NAME" --clobber
fi

echo "🎉 Done!"
