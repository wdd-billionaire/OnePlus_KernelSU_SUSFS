#!/usr/bin/env bash
set -euo pipefail
TASK_SOURCE="$(cd "$(dirname "$0")" && pwd)"
TASK_ROOT="${RUNNER_TEMP:-/tmp}/piano-kernel"
mkdir -p "$TASK_ROOT" "$GITHUB_WORKSPACE/piano-dist"
cd "$TASK_ROOT"
git config --global user.name 'Kernel Builder'
git config --global user.email 'kernel-builder@users.noreply.github.com'
curl --fail --retry 3 -L https://storage.googleapis.com/git-repo-downloads/repo -o repo
chmod +x repo
./repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6-2026-01 --depth=1 --no-clone-bundle --repo-rev=v2.61
./repo sync -c -j4 --no-tags --no-clone-bundle --fail-fast
# Pin the source revision, whose Makefile is exactly Linux 6.6.118.
git -C common fetch --depth=1 origin refs/tags/android15-6.6-2026-01_r1
git -C common checkout --detach FETCH_HEAD
grep -qx 'SUBLEVEL = 118' common/Makefile
./repo manifest -r > "$GITHUB_WORKSPACE/piano-dist/source-manifest.xml"
git clone https://github.com/tiann/KernelSU.git KernelSU
git -C KernelSU checkout --detach 0c0fdb960178fa12d80d6cbcfdcb6ad8be6a865d
ln -s ../../KernelSU/kernel common/drivers/kernelsu
printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> common/drivers/Makefile
sed -i '/endmenu/i source "drivers/kernelsu/Kconfig"' common/drivers/Kconfig
patch -d common -p1 --fuzz=0 < "$TASK_SOURCE/sysvipc-kabi.patch"
cp "$TASK_SOURCE/container.fragment" common/arch/arm64/configs/piano.fragment
# Preserve vendor-module vermagic. The artifact and provenance identify this build.
cat > common/scripts/setlocalversion <<'SCRIPT'
#!/bin/sh
printf '%s\n' '-android15-8-gc44b714366cc-abogki519650608-4k'
SCRIPT
chmod +x common/scripts/setlocalversion
python3 - <<'PY'
p='common/BUILD.bazel'
s=open(p).read().replace('"kmi_symbol_list_strict_mode": True,','"kmi_symbol_list_strict_mode": False,').replace('"trim_nonlisted_kmi": True,','"trim_nonlisted_kmi": False,')
s=s.replace('        "protected_exports_list": "android/abi_gki_protected_exports_aarch64",\n','')
open(p,'w').write(s)
PY
export KBUILD_BUILD_USER=piano-builder KBUILD_BUILD_HOST=github-actions
export KBUILD_BUILD_VERSION=1
tools/bazel run --config=fast --lto=thin --jobs=3 \
  --defconfig_fragment=//common:arch/arm64/configs/piano.fragment \
  //common:kernel_aarch64_dist -- --dist_dir="$TASK_ROOT/dist" 2>&1 | tee "$GITHUB_WORKSPACE/piano-dist/build.log"
cp "$TASK_ROOT/dist/Image" "$GITHUB_WORKSPACE/piano-dist/Image"
cp "$TASK_ROOT/dist/.config" "$GITHUB_WORKSPACE/piano-dist/kernel.config"
cp "$TASK_ROOT/dist/Module.symvers" "$GITHUB_WORKSPACE/piano-dist/Module.symvers"
cp "$TASK_ROOT/dist/System.map" "$GITHUB_WORKSPACE/piano-dist/System.map"
for key in SYSVIPC IPC_NS PID_NS USER_NS DEVTMPFS ARM64_4K_PAGES KSU; do
  grep -qx "CONFIG_${key}=y" "$GITHUB_WORKSPACE/piano-dist/kernel.config"
done
{
  echo 'Target: Xiaomi Pad 8 Pro (piano), Android 15 GKI ABI, Linux 6.6.118, 4K pages'
  echo "Kernel source: $(git -C common rev-parse HEAD)"
  echo "KernelSU source: $(git -C KernelSU rev-parse HEAD)"
  echo "Build workflow: $GITHUB_SHA"
  echo 'Unverified on hardware until temporary boot testing succeeds.'
} > "$GITHUB_WORKSPACE/piano-dist/BUILD-INFO.txt"
cd "$GITHUB_WORKSPACE/piano-dist"
sha256sum Image kernel.config Module.symvers System.map source-manifest.xml BUILD-INFO.txt > SHA256SUMS
