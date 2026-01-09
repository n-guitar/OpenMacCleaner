#!/bin/bash
SRC="/Users/naoto/.gemini/antigravity/brain/e9139be4-f4ab-40c5-8ada-c823315ff8ae/uploaded_image_1767936280455.jpg"
DST="/Users/naoto/Scratch/open-mac-cleaner/OpenMacCleanerApp/OpenMacCleanerApp/Assets.xcassets/AppIcon.appiconset"

# Ensure destination exists
mkdir -p "$DST"

echo "Generating icons from $SRC..."

sips -s format png -z 16 16 "$SRC" --out "$DST/icon_16x16.png"
sips -s format png -z 32 32 "$SRC" --out "$DST/icon_16x16@2x.png"
sips -s format png -z 32 32 "$SRC" --out "$DST/icon_32x32.png"
sips -s format png -z 64 64 "$SRC" --out "$DST/icon_32x32@2x.png"
sips -s format png -z 128 128 "$SRC" --out "$DST/icon_128x128.png"
sips -s format png -z 256 256 "$SRC" --out "$DST/icon_128x128@2x.png"
sips -s format png -z 256 256 "$SRC" --out "$DST/icon_256x256.png"
sips -s format png -z 512 512 "$SRC" --out "$DST/icon_256x256@2x.png"
sips -s format png -z 512 512 "$SRC" --out "$DST/icon_512x512.png"
sips -s format png -z 1024 1024 "$SRC" --out "$DST/icon_512x512@2x.png"

echo "Done."
