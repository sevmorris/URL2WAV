#!/usr/bin/env zsh
# release.sh — Build, verify, package, and publish a URL2WAV release.
#
# Usage: ./release.sh <version>
#   e.g. ./release.sh 1.0.0
#
# Requires: xcodebuild, hdiutil, gh (GitHub CLI), git, xcodegen

set -euo pipefail

REPO="sevmorris/URL2WAV"

# ── Args ──────────────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 1.0.0"
    exit 1
fi

VERSION="$1"
TAG="v${VERSION}"
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="$SCRIPT_DIR"
YAML="$PROJECT_DIR/project.yml"
PROJECT="$PROJECT_DIR/URL2WAV.xcodeproj"
SCHEME="URL2WAV"
DERIVED_DATA="/tmp/url2wav_build_${VERSION}"
APP_PATH="$DERIVED_DATA/Build/Products/Release/URL2WAV.app"
STAGING="/tmp/url2wav_dmg_${VERSION}"
DMG="/tmp/URL2WAV-${TAG}.dmg"
MOUNT="/tmp/url2wav_verify_${VERSION}"

# ── Helpers ───────────────────────────────────────────────────────────────────
step()  { echo "\n▶ $*"; }
ok()    { echo "  ✓ $*"; }
fail()  { echo "\n  ✗ $*" >&2; exit 1; }

cleanup() {
    rm -rf "$STAGING" "$MOUNT" "$DERIVED_DATA"
    rm -f "$DMG"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
step "Preflight checks"
for cmd in xcodebuild hdiutil gh git xcodegen; do
    command -v $cmd &>/dev/null || fail "'$cmd' not found in PATH"
done
ok "Tools present"

cd "$PROJECT_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    fail "Working tree is dirty — commit or stash changes before releasing"
fi
ok "Working tree clean"

if git tag | grep -q "^${TAG}$"; then
    fail "Tag $TAG already exists — has this version been released?"
fi
ok "Tag $TAG is available"

# ── Version bump ──────────────────────────────────────────────────────────────
step "Bumping version to $VERSION"
CURRENT=$(grep -E "CFBundleShortVersionString:" "$YAML" | head -1 | grep -o '[0-9][0-9.]*')
if [[ "$CURRENT" == "$VERSION" ]]; then
    ok "Already at $VERSION"
else
    sed -i '' "s/CFBundleShortVersionString: \"${CURRENT}\"/CFBundleShortVersionString: \"${VERSION}\"/g" "$YAML"
    # Also update CFBundleVersion
    sed -i '' "s/CFBundleVersion: \"[0-9]*\"/CFBundleVersion: \"${VERSION//./}\"/g" "$YAML"
    
    xcodegen generate
    ok "Bumped $CURRENT → $VERSION and regenerated project"
fi

if [[ -n "$(git status --porcelain)" ]]; then
    git add "$YAML" "$PROJECT/project.pbxproj"
    git commit -m "Bump version to $VERSION"
    ok "Committed version bump"
else
    ok "All files already up to date"
fi

# ── Build ─────────────────────────────────────────────────────────────────────
step "Building (clean, Release)"
rm -rf "$DERIVED_DATA"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet
ok "Build complete"

# ── Sign ──────────────────────────────────────────────────────────────────────
step "Codesigning app bundle"
IDENTITY="Developer ID Application: Seven Morris (T9RLNAXPWU)"
ENTITLEMENTS="$PROJECT_DIR/URL2WAV/URL2WAV.entitlements"

# Sign the app bundle with Hardened Runtime
codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP_PATH"
ok "Codesigning complete"

# ── Verify app version ────────────────────────────────────────────────────────
step "Verifying built app version"
BUILT_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
[[ "$BUILT_VERSION" == "$VERSION" ]] || \
    fail "App version mismatch: expected $VERSION, got $BUILT_VERSION"
ok "App reports $BUILT_VERSION"

# ── Stage DMG contents ────────────────────────────────────────────────────────
step "Staging DMG contents"
rm -rf "$STAGING"
mkdir "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
ok "App, Applications alias"

# ── Create DMG ────────────────────────────────────────────────────────────────
step "Creating DMG"
rm -f "$DMG"
hdiutil create \
    -volname "URL2WAV $TAG" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -o "$DMG" \
    -quiet
ok "Created $(du -sh $DMG | cut -f1) DMG"

# ── Notarize ──────────────────────────────────────────────────────────────────
step "Notarizing DMG"
xcrun notarytool submit "$DMG" --wait --keychain-profile "WoWoNotary"
xcrun stapler staple "$DMG"
ok "Notarization complete"

# ── Verify DMG ────────────────────────────────────────────────────────────────
step "Verifying DMG contents"
rm -rf "$MOUNT"
mkdir "$MOUNT"
hdiutil attach "$DMG" -mountpoint "$MOUNT" -quiet -nobrowse
DMG_VERSION=$(defaults read "$MOUNT/URL2WAV.app/Contents/Info.plist" CFBundleShortVersionString)
hdiutil detach "$MOUNT" -quiet
[[ "$DMG_VERSION" == "$VERSION" ]] || \
    fail "DMG version mismatch: expected $VERSION, got $DMG_VERSION"
ok "DMG contains $DMG_VERSION"

# ── Tag and push ──────────────────────────────────────────────────────────────
step "Tagging and pushing"
git tag "$TAG"
git push
git push origin "$TAG"
ok "Pushed $TAG"

# ── GitHub release ────────────────────────────────────────────────────────────
step "Creating GitHub release"
CHANGES=$(git log -n 5 --pretty=format:"- %s" | grep -v "Bump version")
RELEASE_NOTES="### Changes
${CHANGES}"

gh release create "$TAG" "$DMG" \
    --repo "$REPO" \
    --title "URL2WAV $TAG" \
    --notes "$RELEASE_NOTES"
ok "Release published"

# ── Clean up temp files ───────────────────────────────────────────────────────
step "Cleaning up"
rm -rf "$STAGING" "$MOUNT" "$DERIVED_DATA"
# Keep DMG in project root for easy access if needed, or just delete it
# rm -f "$DMG"
ok "Temp files removed"

RELEASE_URL="https://github.com/${REPO}/releases/tag/${TAG}"
echo "\n✓ URL2WAV $TAG released successfully."
echo "  $RELEASE_URL"
