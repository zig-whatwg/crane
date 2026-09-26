# Testing: A new Window per navigation multiplies whatever leaks per realm

**Date**: 2026-09-26
**Lesson**: Making a new Window for each cross-document navigation added a realm per navigation, and the whole-page retention already present kept every one.

**Why**: Retention that costs one realm per page costs one realm per navigation once navigations make realms.

**What Happened**: About 10% more retained heap - ~120 more native contexts and ~100 MB by file 361 of a 367-file shard (1,206 MB against 1,105 MB) - turned a long sweep near V8's limit into `FatalProcessOutOfMemory` at file 362 in all three tip builds. The file passes alone. A plausible single cause, the strong handle to the old global object, was measured and ruled out: weakening it did not move the curve.

**Fix**: Pending - find the retainers of detached realms (docs/lessons/debugging-find-what-keeps-a-page-alive-count-native.md).

**Takeaway**: **Compare the heap and native_contexts columns between the two binaries at the same file index before crediting a memory fix.**
