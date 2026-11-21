#!/usr/bin/env bash
# Draws every app icon size natively (no downscaling) plus the logo lockup.
set -euo pipefail
cd "$(dirname "$0")/.."
D=Ginkgo/Resources/Assets.xcassets/AppIcon.appiconset
for px in 40 58 60 80 87 120 180 1024; do
  swift scripts/draw-app-icon.swift icon "$D/AppIcon-$px.png" "$px"
done
mkdir -p brand
swift scripts/draw-app-icon.swift lockup brand/ginkgo-logo.png 2048
swift scripts/draw-app-icon.swift icon brand/ginkgo-mark.png 2048
echo "Icons and brand files drawn."
