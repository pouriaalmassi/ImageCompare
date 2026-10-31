#!/bin/zsh
# Builds a Release ImageCompare.app and packages it into dist/ImageCompare-<version>.dmg.
#
# Usage: ./scripts/build-dmg.sh
#
# Signing: ad-hoc by default, which runs on this Mac but triggers Gatekeeper elsewhere.
# To sign for distribution, set SIGN_IDENTITY (e.g. "Developer ID Application: Name (TEAMID)")
# and DEVELOPMENT_TEAM. Notarization is not performed.

set -euo pipefail

readonly PROJECT_ROOT=${0:A:h:h}
readonly APP_NAME="ImageCompare"
readonly SCHEME="ImageCompare"
readonly BUILD_DIR="$PROJECT_ROOT/build"
readonly DIST_DIR="$PROJECT_ROOT/dist"
readonly SIGN_IDENTITY=${SIGN_IDENTITY:--}

signing_settings=(CODE_SIGN_IDENTITY="$SIGN_IDENTITY")
if [[ -n ${DEVELOPMENT_TEAM:-} ]]; then
	signing_settings+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Manual)
fi

echo "==> Building $APP_NAME (Release)"
xcodebuild \
	-project "$PROJECT_ROOT/$APP_NAME.xcodeproj" \
	-scheme "$SCHEME" \
	-configuration Release \
	-destination "generic/platform=macOS" \
	-derivedDataPath "$BUILD_DIR/DerivedData" \
	"${signing_settings[@]}" \
	-quiet \
	build

readonly APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
if [[ ! -d $APP_PATH ]]; then
	echo "error: build succeeded but $APP_PATH was not found" >&2
	exit 1
fi

readonly VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
readonly DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Verifying signature"
codesign --verify --deep --strict "$APP_PATH"

echo "==> Packaging $DMG_PATH"
readonly STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
# Lets users install by dragging the app onto the Applications shortcut.
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
	-volname "$APP_NAME" \
	-srcfolder "$STAGING_DIR" \
	-fs HFS+ \
	-format UDZO \
	-quiet \
	"$DMG_PATH"
rm -rf "$STAGING_DIR"

hdiutil verify -quiet "$DMG_PATH"
echo "==> Done: $DMG_PATH"
