# Architecture: A stale weak callback's `Registry.remove` evicts the LIVE entry at a recycled address

**Date**: 2026-09-22
**Lesson**: The `InstanceRegistry.createIn` hazard above has a named actor now,
and it is not the arena - it is a weak callback for an instance that died
earlier, running `Registry.remove` on an address that a new instance has since
taken.

**What Happened**: `custom-elements/Document-createElement.html` died with SEGV
at 0x0 in `mem.Allocator.rawAlloc` under `Node.init`, at the bottom of an
iframe's insertion steps. Instrumented, with the iframe document's
InternalState pointer printed at each step:

    A  after Document.init:            internal=@124d31490  alloc.vtable=@106311018
    B  before the second createElement: internal=@124d31490  alloc.vtable=@0

Same block, allocator zeroed in between. Between A and B is the `appendChild`
of the new document's `<html>`, and `createChildContext` forces a GC there.
That GC runs the wrapper cache's weak callback for an EARLIER iframe document
that had already died - its slab slot reissued to this one. `Document.deinit`
on that stale instance calls `Registry.remove(address)`, the registry is keyed
on the address, so it removes the live document's entry and returns its block
to the arena, whose free-list write zeroes the allocator field. The next
`getInternal` still finds the block (the pointer was cached) and hands the
zeroed allocator to `Node.init`.

It was not `ArenaAllocator.get()`: that pointer was identical on every one of
the 106 logged calls, before and after. The `|*g|` rewrite stays because it
cannot be less correct, but it fixed nothing and the commit says so.

**Fix**: the slab stamps a generation per slot and the wrapper cache refuses a
mismatch (644f5e44d) - that closed connected-callbacks' teardown crash.
Document-createElement's SEGV survived it: its actor was a size-mismatched
state free ([architecture-instance-init-sizes-the-state-by-the-caller-s](architecture-instance-init-sizes-the-state-by-the-caller-s.md)), not a stale callback. The reasoning below is
kept as written. It needs identity, not an address: either the slot records a
generation the slab stamps on every alloc and `remove` refuses a mismatch, or
weak callbacks for bulk-freed instances are cancelled when the slot is freed.
Both are registry/slab design changes. `custom-elements/connected-callbacks.html`'s
exit crash is the same hazard from the other side - the exit sweep reading
`named_node_map` out of a registry block the arena already reissued.

**Takeaway**: **An address is not an identity, and a registry keyed on one will
act on whoever lives there now.** The order of failures is: bulk-freed slot ->
reissued -> stale weak callback -> `remove` on the newcomer. Any fix has to
break that chain at the callback, not at the allocator.
