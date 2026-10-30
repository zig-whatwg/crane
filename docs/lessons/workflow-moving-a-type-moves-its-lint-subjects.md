# Workflow: Moving a type moves its lint subjects - re-key them, never let them drop

**Date**: 2026-10-30
**Lesson**: Moving a state type out of an impl into src/dom moved two lints' subjects with it: one lint would have reported a new key, the other would have lost sight of the type, and nothing would have said so.

**Why**: Crane's ratchet lints key their findings by path. Some also decide what to look at by path or by file contents:
- lint-tombstones flags a hash map only in a file that both declares it and removes from it;
- lint-refcount's rule 2 treats every container as node state only in the node interfaces' impl files.

A move changes every one of those facts at once. A baseline then shows a "paid down" count where no debt was paid, or a check silently stops checking.

**What Happened**: Impls batch 7 (lane impls7) moved Document's `InternalState` from `src/webidl/impls/Document.zig` to `src/dom/document_state.zig`, so that `dom.document_internals` no longer names the impl.
- Its two unguarded maps, `InternalState.module_map` and `InternalState.import_map_imports`, were in tools/tombstones_baseline.txt under the old path.
- The removals from those maps stayed in Document.zig and document_internals.zig. After the move, no file both declared and removed from either map, so lint-tombstones dropped them: its count fell by two with nothing guarded.
- lint-refcount stopped treating Document's state as node state.

Both gaps came from reading the lints' rules before the gate, not from a failure.

**Fix**:
1. The map removals became the moved type's own steps (`removeModuleMapEntry`, `removeImport`), so the declaring file removes from them again and the lint sees both maps there.
2. lint-tombstones gained `-- --move '<old key>' '<new key>'` (lint-global-state's `--rename` is the model). It records the same debt under its new path only when:
   - the old key has left the scan;
   - the new key is not in the baseline;
   - both name the same qualified map;
   - the counts are equal.
3. lint-refcount lists `src/dom/document_state.zig` as moved node state for rule 2. Rule 3 stays with the impl, which still makes and frees the state.

**Takeaway**: **Before moving a type to another file, read every path-keyed lint's rules - tombstones, refcount, global state, platform, engine, impls. A count that drops without a fix is a lint that stopped looking: re-key the debt with the tool, and keep the coverage.**
