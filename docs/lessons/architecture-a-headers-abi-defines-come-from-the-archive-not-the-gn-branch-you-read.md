# Architecture: A header's ABI defines come from the archive, not from the GN branch you read

**Date**: 2026-11-08
**Lesson**: cppgc's public headers inline `Member`'s pointer compression, the write barrier's fast path and the cage constants under five preprocessor defines. The design for the wrapper redesign listed three, the ones BUILD.gn's caged-heap branch turns on. The archive also had the two that `gni/v8.gni` turns on by default.

**Why**: An embedder compiles V8's headers with whatever `-D` flags its own build passes. A define that changes an inline function or a constant changes the code the embedder generates, and nothing checks it against the library: neither the compiler nor the linker sees a mismatch, and no symbol goes missing. In 13.1.203, `cppgc_enable_caged_heap` (BUILD.gn, 64-bit) forces CPPGC_YOUNG_GENERATION and CPPGC_POINTER_COMPRESSION. Separately, gni/v8.gni defaults `cppgc_enable_slim_write_barrier = true` and `cppgc_enable_larger_cage = true`. CPPGC_ENABLE_LARGER_CAGE moves `kPointerCompressionShift` from 1 to 3 (include/cppgc/internal/api-constants.h).

**What Happened**: Lane wr2 (P3: a CppHeap per agent) checked the archive before adding the design's three defines to build.zig.
- Reading the archive gave four facts:
  - `nm` finds `CombinedWriteBarrierSlow`, so the archive has CPPGC_SLIM_WRITE_BARRIER.
  - `CageBaseGlobal::g_base_` is defined in member-storage.o.
  - Its initial value, the cage alignment's mask, is `0x3ffffffff` (`otool -s __DATA __data` on macOS, `objdump -s -j .data` on Linux). That means CPPGC_ENABLE_LARGER_CAGE: a 16 GB alignment, shift 3.
  - out/ios-arm64's mask is `0xffffffff`: built without the larger cage.
- With the design's three defines, the headers compress a Member with shift 1 and the library decompresses it with shift 3. A Member reads back another address than it was given, and the marker's first trace of it crashes, far from its cause (risk R7).
- `sizeof(Member) == 4`, the design's ABI check, passes in that state: the size depends on pointer compression alone, not on the shift.

**Fix**:
1. build.zig's `v8WrapperFlags` holds every define of v8_wrapper.cpp in one place: CPPGC_CAGED_HEAP, CPPGC_YOUNG_GENERATION, CPPGC_POINTER_COMPRESSION, CPPGC_SLIM_WRITE_BARRIER, and CPPGC_ENABLE_LARGER_CAGE except for an iOS archive. The comment says how each was read from the archive.
2. tests/v8/cpp_heap_test.zig checks behaviour, not only size: a Member must read back the object it was given before anything collects, then survive a forced collection while rooted.
3. Lane wr2's `.wr2/abi-check.sh` (saved with its handoff) reads the five facts from any archive. Run it on every archive a build links, each OS's included: the iOS one differed.

**Takeaway**: **When a library's headers change inline code under build-time defines, read the defines from the built archive - its symbols and its initialised data - and test the behaviour they govern (a value round-trips), not a size two configurations share.**
