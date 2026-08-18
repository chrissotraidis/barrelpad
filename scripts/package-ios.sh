#!/usr/bin/env bash
# Audit an iPhoneOS BarrelPad app and wrap it as a ROM-free, re-signable IPA.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build-ios-device/BarrelPad.app}"

if [[ "$APP" != /* ]]; then
  APP="$ROOT/$APP"
fi

fail() {
  echo "BarrelPad IPA packaging failed: $*" >&2
  exit 1
}

BINARY="$APP/BarrelPad"
[[ -d "$APP" && -f "$BINARY" && -f "$APP/Info.plist" ]] ||
  fail "device app not found: $APP"

platform="$(xcrun vtool -show-build "$BINARY" | awk '$1 == "platform" { print $2; exit }')"
[[ "$platform" == "IOS" ]] || fail "expected an iPhoneOS app, found platform '$platform'"
[[ "$(lipo -archs "$BINARY")" == "arm64" ]] || fail "device executable is not arm64-only"

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
minimum_os="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")"
device_families="$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' "$APP/Info.plist")"

[[ "$bundle_id" == "com.chrissotraidis.barrelpad" ]] ||
  fail "unexpected bundle identifier: $bundle_id"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid app version: $version"
[[ "$build_number" =~ ^[0-9]+$ ]] || fail "invalid build number: $build_number"
grep -Eq '(^|[[:space:]])1($|[[:space:]])' <<<"$device_families" ||
  fail "app does not support iPhone"
grep -Eq '(^|[[:space:]])2($|[[:space:]])' <<<"$device_families" ||
  fail "app does not support iPad"

for required in "$APP/Assets.car" "$APP/AppIcon60x60@2x.png" \
  "$APP/AppIcon76x76@2x~ipad.png" "$APP/PrivacyInfo.xcprivacy"; do
  [[ -f "$required" ]] || fail "required bundle resource is missing: $required"
done
plutil -lint "$APP/PrivacyInfo.xcprivacy" >/dev/null || fail "privacy manifest is invalid"

unexpected_runtime="$(otool -L "$BINARY" | awk 'NR > 1 { print $1 }' | grep -Ev '^(/System/Library/|/usr/lib/)' || true)"
[[ -z "$unexpected_runtime" ]] || fail "unbundled runtime dependency: $unexpected_runtime"
! otool -l "$BINARY" | grep -q 'cmd LC_RPATH' || fail "executable contains a build-directory LC_RPATH"
if [[ -n "${HOME:-}" ]] && strings "$BINARY" | grep -Fq "$HOME/"; then
  fail "executable contains a personal build path"
fi

license_sources=(
  "$ROOT/RIGHTS_AND_LICENSES.md"
  "$ROOT/sources/goldenballoon/LICENSE"
  "$ROOT/sources/goldenballoon/NOTICE.md"
  "$ROOT/sources/goldenballoon/THIRD_PARTY.md"
  "$ROOT/ref/diddy-kong-racing/LICENSE.md"
  "$ROOT/build-deps/src/SDL2-2.32.10/LICENSE.txt"
)
for license in "${license_sources[@]}"; do
  [[ -f "$license" ]] || fail "required rights or license file is missing: $license"
done

output="${2:-$ROOT/dist/BarrelPad-${version}-unsigned.ipa}"
if [[ "$output" != /* ]]; then
  output="$ROOT/$output"
fi

package_root="$(mktemp -d /tmp/barrelpad-package.XXXXXX)"
trap 'rm -rf "$package_root"' EXIT
mkdir -p "$package_root/Payload"
ditto --norsrc "$APP" "$package_root/Payload/BarrelPad.app"
package_app="$package_root/Payload/BarrelPad.app"
package_binary="$package_app/BarrelPad"

codesign --remove-signature "$package_app" >/dev/null 2>&1 || true
rm -rf "$package_app/_CodeSignature"
rm -f "$package_app/embedded.mobileprovision"

mkdir -p "$package_app/Licenses"
cp "$ROOT/RIGHTS_AND_LICENSES.md" "$package_app/Licenses/BarrelPad-RIGHTS-AND-LICENSES.md"
cp "$ROOT/sources/goldenballoon/LICENSE" "$package_app/Licenses/GoldenBalloon-LICENSE"
cp "$ROOT/sources/goldenballoon/NOTICE.md" "$package_app/Licenses/GoldenBalloon-NOTICE.md"
cp "$ROOT/sources/goldenballoon/THIRD_PARTY.md" "$package_app/Licenses/GoldenBalloon-THIRD-PARTY.md"
cp "$ROOT/ref/diddy-kong-racing/LICENSE.md" "$package_app/Licenses/DKR-Decomp-LICENSE.md"
cp "$ROOT/build-deps/src/SDL2-2.32.10/LICENSE.txt" "$package_app/Licenses/SDL2-LICENSE.txt"

forbidden_pattern='\.(v64|z64|n64|rom|ndd|sra|eep|fla|mpk|sav|p12|mobileprovision|provisionprofile|cer|key|pem)$|(^|/)\.env($|\.)|(^|/)(baserom|extracted)(/|$)'
forbidden_paths="$(find "$package_app" -type f -print | sed "s#^$package_root/##" | grep -Ei "$forbidden_pattern" || true)"
[[ -z "$forbidden_paths" ]] || fail "staging contains prohibited data: $forbidden_paths"

known_rom_sha1='03f04dfe0c34e8bad370aa4b68f4bb8ed3429fde'
while IFS= read -r -d '' file_path; do
  magic="$(od -An -tx1 -N4 "$file_path" 2>/dev/null | tr -d ' \n')"
  case "$magic" in
    80371240|37804012|40123780) fail "staging contains an N64 ROM image: $file_path" ;;
  esac
  file_sha1="$(shasum -a 1 "$file_path" | awk '{print $1}')"
  [[ "$file_sha1" != "$known_rom_sha1" ]] || fail "staging contains the supported DKR ROM"
done < <(find "$package_app" -type f -print0)

! otool -l "$package_binary" | grep -q 'LC_CODE_SIGNATURE' ||
  fail "staging executable still contains a code signature"
[[ ! -d "$package_app/_CodeSignature" && ! -f "$package_app/embedded.mobileprovision" ]] ||
  fail "staging still contains signing material"

find "$package_root/Payload" -exec touch -h -t 202001010000 {} +
mkdir -p "$(dirname "$output")"
temporary_ipa="$package_root/BarrelPad.ipa"
(
  cd "$package_root"
  export COPYFILE_DISABLE=1
  find Payload -print | LC_ALL=C sort | zip -X -q -9 "$temporary_ipa" -@
)

entries="$(unzip -Z1 "$temporary_ipa")"
grep -Fxq 'Payload/BarrelPad.app/BarrelPad' <<<"$entries" || fail "IPA executable is missing"
grep -Fxq 'Payload/BarrelPad.app/Info.plist' <<<"$entries" || fail "IPA Info.plist is missing"
archive_matches="$(grep -Ei "$forbidden_pattern|_CodeSignature/" <<<"$entries" || true)"
[[ -z "$archive_matches" ]] || fail "IPA contains prohibited data: $archive_matches"
unzip -tq "$temporary_ipa" >/dev/null || fail "IPA ZIP integrity check failed"

mv -f "$temporary_ipa" "$output"
checksum="$output.sha256"
(
  cd "$(dirname "$output")"
  shasum -a 256 "$(basename "$output")" > "$(basename "$checksum")"
)

echo "Packaged audited BarrelPad $version ($build_number) for iPhone and iPad"
echo "Minimum iOS/iPadOS: $minimum_os"
echo "Unsigned IPA: $output"
cat "$checksum"
echo "This ROM-free artifact must be re-signed before installation on a standard device."
