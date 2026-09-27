# Testing: A new Window per navigation multiplies whatever leaks per realm

**Date**: 2026-09-26
**Lesson**: Making a new Window for each cross-document navigation added a realm per navigation, and the whole-page retention already present kept every one.

**Why**: Retention that costs one realm per page costs one realm per navigation once navigations make realms.

**What Happened**: About 10% more retained heap - ~120 more native contexts and ~100 MB by file 361 of a 367-file shard (1,206 MB against 1,105 MB) - turned a long sweep near V8's limit into `FatalProcessOutOfMemory` at file 362 in all three tip builds. The file passes alone. A plausible single cause, the strong handle to the old global object, was measured and ruled out: weakening it did not move the curve.

**Fix**: Pending - find the retainers of detached realms (docs/lessons/debugging-find-what-keeps-a-page-alive-count-native.md).

**Takeaway**: **Compare the heap and native_contexts columns between the two binaries at the same file index before crediting a memory fix.**

**Status (2026-09-26)**: found. Every frame realm was pinned by a TypeError that its own setup threw and leaked (`self`/`frames` assigned before the realm had a Window), and a frame's last realm by the [Replaceable] setter's unreleased argument handle - see docs/lessons/architecture-engine-code-defines-a-realm-s-properties-it-never-assigns-them.md. With realms made per navigation it was 26 V8 out-of-memory crashes in the a680e6733 sweep.
