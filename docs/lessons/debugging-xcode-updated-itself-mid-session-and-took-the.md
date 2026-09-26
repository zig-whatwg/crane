# Debugging: Xcode updated itself mid-session and took the build's SDK with it

**Date**: 2026-09-22
**Lesson**: A build error naming a file that does not exist means the toolchain
moved; check that before the code.

**What Happened**: `zig build test` failed with `unable to find libSystem
system library` and `failed to open .../SDKs/MacOSX26.5.sdk/.../
SystemConfiguration.tbd: FileNotFound`, while a `wpt-runner` build in the same
chain had passed minutes earlier. `ls` of Xcode's SDK folder showed only
`MacOSX.sdk` and two `27` symlinks; 435 cache manifests in the build cache still
named `MacOSX26.5.sdk`, the newest written that morning. Xcode had updated its
SDK from 26.5 to 27.0 during the run. The next build then failed for real, on
the `INFINITY` incompatibility described under "Before every commit".

**Fix**: `build.zig` now selects a buildable SDK itself (`useBuildableMacosSdk`).
To triage the next one: `xcrun --sdk macosx --show-sdk-version`,
`ls /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/
/Library/Developer/CommandLineTools/SDKs/`, and `grep -rl <old path>` in the
cache's `h/` directory to date the last build that saw it.

**Takeaway**: **An error that names a missing SDK file is about the machine,
not the tree.** Ten seconds of `ls` beats re-running the suite.
