# Experimental Firefox ESR ARM64 KGSL adapter

This build preserves the Firefox RDD sandbox while adding opt-in brokered
access to a root-owned KGSL character device and one Termux VA bridge socket.
It is for the DroidSpaces Debian environment on the OnePlus tablet.
The exact source archive is verified with a pinned SHA-512 checksum.

The workflow runs on the standard GitHub-hosted ARM64 runner with four build
workers. It uploads a package and logs as short-lived Actions artifacts.
It does not publish a release or deploy to a device. A successful compilation
does not establish that hardware decoding or sandbox isolation works on the
tablet; those runtime tests are still required before daily use.

The companion Mesa/Android MediaCodec bridge is built separately. This Firefox
package alone is not a complete installation. Current bridge validation covers
H.264, HEVC and VP9; AV1 hardware decoding remains disabled pending repair.

All experimental access is gated by `MOZ_ENABLE_TERMUX_VA=1`. Do not disable
the RDD, content or GPU sandbox to make this build work.
