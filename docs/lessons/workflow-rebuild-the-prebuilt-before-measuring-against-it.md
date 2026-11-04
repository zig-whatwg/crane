# Workflow: Rebuild the prebuilt before measuring against it

**Date**: 2026-11-04
**Lesson**: Before comparing a rebuilt dependency with its prebuilt, rebuild the prebuilt itself from its tag and compare hashes: lane v8opt1's control build of V8 13.1.203 reproduced jsengines/v8/out/static's three archives byte for byte, which proved the GN arguments, the clang and the SDK, and left ThinLTO and PGO as the only difference between static and official. (out/control was deleted afterwards; its args.gn, PROVENANCE and SHA256SUMS are in chat.local:~/crane-work/v8opt1-bins/control-record/.)

**Why**: Nothing in the tree recorded how out/static was built: no args.gn beside it, a build script whose default version (14.0.10) is not the version it holds (13.1.203), and checkouts beside it at 14.6 and 15.7. A control that only "uses the same arguments" carries every guess into the measurement - a different clang or SDK changes code generation as much as a flag does.

**What Happened**: The archives' own evidence narrowed it down (system libc++: 18,151 `std::__1` symbols and no `std::__Cr`; no Intl; LC_BUILD_VERSION minos 11.0, sdk 26.2), and build.zig's V8 13.1.x setup recipe (829d1ab0128) matched it - scripts/build-v8-static.sh's list less four arguments that do nothing at 13.1.203. A 13.1.203 checkout at that tag's DEPS (Chromium clang llvmorg-20-init-3847-g69c43468) with Xcode 26.2's SDK built archives whose SHA-256s equal out/static's on chat.local and on the Mac (ca263c83... libv8_monolith.a). Two obstacles on the way: 13.1.203's `vpython3_common` hook asks for numpy 1.21.1 wheels for Python 3.8 that Chromium's package index no longer serves (sync with `--nohooks` and run the two hooks the build needs: build/util/lastchange.py and the builtins-PGO profiles, fetched over HTTPS), and chat.local's xcode-select points at the Command Line Tools, so Chromium's build/config/apple/sdk_info.py fails on `xcodebuild -version` until DEVELOPER_DIR names Xcode.

**Fix**: scripts/build-v8-official.sh `checkout` + `control`; the hashes are in its install step's SHA256SUMS. With the control identical, the A/B and the speed pairs compare out/static with out/official directly.

**Takeaway**: **A byte-identical rebuild turns "the prebuilt's settings" from an assumption into a fact; do it first, and every later difference has one cause.**
