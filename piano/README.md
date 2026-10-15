# Xiaomi Pad 8 Pro Debian kernel

This branch builds an Android 15 GKI 6.6.118 kernel for testing DroidSpaces on Xiaomi Pad 8 Pro (piano).

- AOSP source tag: android15-6.6-2026-01_r1.
- Official KernelSU v3.3.1, pinned to commit 0c0fdb960178fa12d80d6cbcfdcb6ad8be6a865d.
- 4K pages; PID, IPC and user namespaces; devtmpfs and container networking.
- DroidSpaces upstream SYSVIPC ABI padding patch using slots 6/7/8.
- No vendor modules or device trees are replaced by this build.

GitHub Actions builds on pushes to this branch and publishes a prerelease test artifact with configuration, source manifest and SHA256 checksums. Downloading or compiling an image does not establish device compatibility. Test with a temporary boot, then verify Android, vendor drivers, GPU, namespaces, the Debian desktop and video decode before installing.

The stock kernel release suffix is retained for vendor-module vermagic compatibility; BUILD-INFO.txt and artifact checksums identify the custom build.
