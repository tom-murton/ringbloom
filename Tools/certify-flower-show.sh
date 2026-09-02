#!/bin/zsh
set -euo pipefail

workspace_root=${0:A:h:h}
derived_data="$workspace_root/.build/AuthoringDerivedData"
runner="$derived_data/Build/Products/Release/FlowerShowAuthoring"
report="$workspace_root/FLOWER_SHOW_V3_CERTIFICATION_REPORT.md"

cd "$workspace_root"
xcodegen generate
xcodebuild \
  -project Ringbloom.xcodeproj \
  -scheme FlowerShowAuthoring \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  build
"$runner" --certify --report "$report"
