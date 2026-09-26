# Architecture: InstanceRegistry.createIn destabilises the DOM

**Date**: 2026-09-21
**Lesson**: Per-instance state taken from the shared arena and returned on `remove` gets reissued under a live reader.

**Why**: `utils.InstanceRegistry` keys on `@intFromPtr(instance)`, and the slab
RECYCLES instance addresses. `createIn` takes a block from the process-wide
`ArenaAllocator`; `remove` returns it to a size-classed free list, from which
the next same-sized request takes it. Anything still holding a `*T` obtained
from `Registry.get()` across that point now writes into a different element's
state.

**What Happened**: Measured in a control worktree at one HEAD, 8 single-process
runs per column, only the state mechanism differing:

    textarea reverted to stubs               0 / 8 aborted
    state via InstanceRegistry.createIn    1-7 / 8 aborted
    same, registry allocation removed        0 / 8 aborted
    state in a by-value map                  0 / 8 aborted

The abort is SIGABRT from a SEGV in `Node.getFirstChild`, reading a corrupted
`node_base` **in a later test file** - so it does not reproduce on the file that
caused it. Which new code was present barely mattered; removing the arena block
fixed it in all four batches.

`gc_bench` has been printing the same hazard all along: *"instance->NodeBase
entries: 1 (keyed on a RECYCLED address, so a stale entry is inherited by the
next object there)"*.

**Fix**: `HTMLOptionElement.zig` and `HTMLTextAreaElement.zig` keep state BY
VALUE in a small `page_allocator` map, created lazily on first assignment - a
stale key then gives a wrong answer instead of corrupting a neighbour, and an
element script never touches allocates nothing.

**This is a workaround.** `HTMLInputElement.zig`, `HTMLFormElement.zig` and ~17
other impls still use `createIn`. `the-input-element/` measured 0 aborts in 4
runs, so do not churn them speculatively - find whoever holds a block past
`ArenaAllocator.destroy` first.

**Takeaway**: **A recycled address plus a recycled block is two aliasing bugs,
not one.** Keying on an address the allocator reuses is survivable; handing out
a pointer into memory the arena will reissue is not.
