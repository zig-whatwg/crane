# Workflow: Build wrapper text rewrites can alter hash commands

**Date**: 2026-10-31
**Lesson**: A launcher that rewrites command text can change arguments to commands other than the build.

**Why**: A substring replacement does not recognize shell words or command boundaries.

**What Happened**: Row131's Images preview prefixed its build with `shasum -a 256 build.zig build.zig.zon`. The adjacent filenames contain `zig build`, which the pool launcher replaces to insert its private cache option. The hash command failed although the native test command ran unchanged. The missing identity check was recovered through a separate read-only pool command before another sync.

**Fix**: Use `./build.zig ./build.zig.zon` as the hash operands, or perform the identity check in a separate light command. Verify the recorded input hashes before accepting the test result. Keep a failing identity check fatal when the launcher script uses it as a precondition.

**Takeaway**: **Check a launcher's transformations against the whole command string, including filenames and quoted data.**
