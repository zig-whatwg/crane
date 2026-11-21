# Workflow: A Zig built for the native macOS target runs only on that macOS or newer

**Date**: 2026-11-21
**Lesson**: A Zig compiler built with no `-Dtarget` on a Mac carries the build host's macOS as its minimum version. To run it anywhere else (GitHub's macOS runners), rebuild it with an explicit deployment target, `-Dtarget=aarch64-macos.14.0-none`, and bootstrap that build from the pinned compiler itself, not from the released 0.17.0.

**Why**: When the target is native, Zig sets the deployment target to the running OS. The pool's pinned 0.17.1-dev+77c319a0f0 was built that way on macOS 27 and stamps `LC_BUILD_VERSION minos 27.0.1`. dyld will not launch that binary on macOS 14, 15 or 26. An explicit target makes it a cross-link against Zig's bundled `lib/libc/darwin/SDKSettings.json`. The pinned tree's copy is only `{"Version":"27.0"}`, and the released 0.17.0's linker, used as the bootstrap, rejects it ("failed to parse Darwin SDK settings: 'MinimalDisplayName' missing"). That is the "explicit -Dtarget failed at the link" which tmp/remote/build-zig017x.sh records. The pinned compiler's own linker reads its own lib.

**What Happened**: Lane z17f packaged the pin as a GitHub release asset for CI (the user's ruling, 2026-11-21). server1's Linux build is a static ELF and runs anywhere. chat.local's macOS build showed minos 27.0.1 under `otool -l`. The first rebuild, bootstrapped from 0.17.0 with an explicit target, failed at the final link. A probe with the pinned zig, `zig build-exe h.zig -target aarch64-macos.14.0-none`, linked a binary with minos 14.0 that ran. The full stage-3 build (BOOT = the pinned zig, everything else build-zig017x.sh's recipe) took 433 s on chat2 and produced minos 14.0.

**Fix**: tmp/remote/build-zig017x-macos14.sh, which is build-zig017x.sh plus `-Dtarget="$TARGET"` and a `BOOT` override:
`BOOT=~/crane-toolchains/zig-<pin>/bin/zig bash build-zig017x-macos14.sh`. Install it into a scratch prefix and check with `otool -l bin/zig | grep -A3 LC_BUILD_VERSION`. Package it without AppleDouble files: `COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs ... -cJf`. The Mac hosts have no `xz`; bsdtar's `-J` does the compression.

**Takeaway**: **Before shipping a compiler built on a Mac, read its `minos`. A native build runs only on the build host's macOS or newer. Rebuild for an explicit deployment target, and bootstrap from the same pin so that the linker and the bundled SDK files match.**
