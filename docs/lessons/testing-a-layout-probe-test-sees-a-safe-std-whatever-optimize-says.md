# Testing: A layout probe test sees a safe std whatever -Doptimize says

**Date**: 2026-11-10
**Lesson**: A tests/<dir>/ test executable's root module is created with no `optimize` (build.zig addTestRootWith). So `builtin.mode` in the test file is Debug, and std - which inherits the root's options - keeps its runtime-safety fields under every `-Doptimize`. Only Crane's own modules take the mode. A size probe built with `-Doptimize=ReleaseFast` therefore still shows ArrayList's 8-B `pointer_stability` lock.

**Why**: Zig gives std the root module's options. Crane's modules are created with -Doptimize's mode, but the test root is not. A struct's layout is decided in the module that declares it: Crane's types follow -Doptimize (an untagged union's safety tag, for one), while std's containers inside them follow the test root.

**What Happened**: Lane nodedata batch 1 built its layout probe (tests/dom/nodedata_layout_probe_test.zig) plain, with `-Doptimize=ReleaseSafe` and with `-Doptimize=ReleaseFast`, to see which sizes move between the release console's mode and crane_fast. All three printed byte-identical tables, and all three said `mode debug`. The node State blocks really are mode-independent: they hold no std safety field and no untagged union. But the probe could not have shown ElementRareData's or AttrNodeList's ReleaseFast size (344 -> 336, 32 -> 24): their ArrayList's lock follows the test root, which stayed safe.

**Fix**:
1. Say which part of a probe's answer follows -Doptimize (Crane's types) and which does not (std's).
2. For a std container's release size, compute it from the container's definition and mark it INFERRED.
3. Or build an executable whose root takes the mode (gc_bench, the console) and read @sizeOf there.

**Takeaway**: **A test executable's std is always a safe build's: a ReleaseFast size of anything holding a std container cannot come from a tests/ probe.**
