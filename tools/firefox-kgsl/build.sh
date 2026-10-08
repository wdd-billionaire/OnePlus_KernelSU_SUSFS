#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true || { echo 'Run this script on the disposable GitHub Actions runner.' >&2; exit 1; }
payload=$(cd "$(dirname "$0")" && pwd)
build_root="$RUNNER_TEMP/firefox-build"
mkdir -p "$build_root/results"
exec > >(tee "$build_root/results/build.log") 2>&1
cd "$build_root"
version=153.4.0esr
archive="firefox-$version.source.tar.xz"
source_sha=79e1f2a0f8c4d156c80b8f4c580aa944600d49cc811f961a3eca251113241638991fda94ccb74a44df9030f643586c41686861333288f13793e621a262a1b131
curl --fail --location --retry 5 --output "$archive" "https://archive.mozilla.org/pub/firefox/releases/$version/source/$archive"
printf '%s  %s\n' "$source_sha" "$archive" | sha512sum --check
mkdir source
tar -xJf "$archive" -C source --strip-components=1
rm "$archive"
cd source
patch --batch --fuzz=0 -p1 < "$payload/firefox-153.4.0-kgsl-rdd.patch"
cp "$payload/mozconfig" .mozconfig
export MOZBUILD_STATE_PATH="$build_root/mozbuild"
export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v rustup >/dev/null; then
  curl --fail --location --retry 5 --output "$build_root/rustup-init" https://static.rust-lang.org/rustup/archive/1.29.1/aarch64-unknown-linux-gnu/rustup-init
  chmod +x "$build_root/rustup-init"
  "$build_root/rustup-init" -y --profile minimal --default-toolchain 1.99.0
fi
# Bootstrap obtains the toolchains selected by this exact ESR source release.
./mach --no-interactive bootstrap --application-choice browser --no-system-changes
rustup toolchain install 1.99.0 --profile minimal
export RUSTUP_TOOLCHAIN=1.99.0
./mach --no-interactive build
./mach --no-interactive build package
cp ../obj/dist/firefox-*.tar.* "$build_root/results/"
cp .mozconfig "$build_root/results/mozconfig"
cp "$payload/firefox-153.4.0-kgsl-rdd.patch" "$build_root/results/"
printf 'Source: Firefox %s\nSource SHA512: %s\nPatch commit: %s\nSandbox: enabled; KGSL access requires MOZ_ENABLE_TERMUX_VA=1\nDevice validation: still required\n' "$version" "$source_sha" "$GITHUB_SHA" > "$build_root/results/BUILD-INFO.txt"
cd "$build_root/results"
sha256sum firefox-*.tar.* > SHA256SUMS
