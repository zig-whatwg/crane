//! A realm's orphan roots: the roots of subtrees removed from their trees
//! while no wrapper reached them, which the realm's end frees.
//!
//! Until reference counting decides (refcount design step 7,
//! tmp/plans/refcount-design.md), a node removed while script holds no
//! wrapper of it - and of nothing in its subtree, since a wrap reaches up to
//! the root - is reached by no tree teardown and no collector: its tree no
//! longer holds it, and no wrapper exists to be collected. It used to stay
//! until its Browser ended (dom.teardown_sweeps freed what was left), so a
//! long-lived Browser grew by every page's orphans
//! (ce3-state-selector-cost: +9,333 nodes a page). Its realm now frees it
//! when it ends, the way it frees its document's tree: the removal records
//! the root here (`record`), and the realm's end - before its coordinated
//! teardown begins, while every object of the realm lives, the conditions of
//! the collector's second pass - frees every root that is still an orphan
//! (`drain`).
//!
//! Only on an engine that tracks wraps (engine.capabilities.wrap_tracking):
//! "no wrapper reached it" is the instance's mark
//! (runtime.instance_lifecycle.provablyUnwrapped), and a missing mark proves
//! nothing elsewhere - there nothing is recorded, and an orphan stays until
//! its Browser ends, as before. Records do not own their roots: a root that
//! script wrapped, a tree took back, or something else freed since is skipped
//! (`Hooks.still_orphan`). A mid-page orphan still waits for its page's end:
//! freeing it at removal is step 7's.
//!
//! The list is the realm's (runtime.ContextData.orphan_roots); single-threaded,
//! like the realm.

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
const instance_lifecycle = @import("instance_lifecycle.zig");
const ContextData = @import("context.zig").ContextData;

/// What the owner of node lifetimes installs (the Node impl, from its
/// installHooks, at process start): runtime cannot read a node.
pub const Hooks = struct {
    /// Whether the recorded root (the same instance - its generation and
    /// cleanup flags were checked) is still an orphan: parentless, its
    /// teardown not begun, and reached by no wrapper.
    still_orphan: *const fn (instance: *Instance) bool,
    /// Free the orphan rooted at `instance` - its whole subtree - through its
    /// own teardown, as a tree's teardown frees a child.
    free: *const fn (instance: *Instance) void,
};

// process-wide: the Node impl's two functions, installed once while the process starts (Node.installHooks) and the same for every Browser and thread; read-only after
var hooks: ?Hooks = null;

/// The owner of node lifetimes installs its hooks: once, while the process
/// starts.
pub fn install(owned: Hooks) void {
    hooks = owned;
}

/// A recorded root, as it was when its removal recorded it.
pub const Record = struct {
    instance: *Instance,
    generation: u64,
};

/// A realm's records. Holds no reference: see the module comment.
pub const List = struct {
    records: std.ArrayListUnmanaged(Record) = .empty,
    /// The realm ended (`drain` ran): nothing is recorded any more.
    ended: bool = false,

    /// Below this many records a full list grows instead of compacting.
    const compact_threshold = 64;

    pub fn deinit(self: *List, allocator: std.mem.Allocator) void {
        self.records.deinit(allocator);
    }

    /// Records still standing for an orphan (tests and diagnostics).
    pub fn count(self: *const List) usize {
        return self.records.items.len;
    }
};

/// Whether `record` still names an orphan.
fn stillOrphan(entry: Record, owned: Hooks) bool {
    if (SlabAllocator.generationOf(entry.instance) != entry.generation) return false;
    if (instance_lifecycle.isCleanupStarted(entry.instance)) return false;
    return owned.still_orphan(entry.instance);
}

/// `instance` was removed from its tree with no wrapper reaching it (the
/// caller checked the mark): its realm `realm` frees it at its end unless a
/// tree or a wrapper takes it first. Recording fails quietly - out of memory,
/// a realm already ended, an engine-less context nothing ends - and the
/// orphan then stays until its Browser ends, as every orphan did before.
pub fn record(realm: *ContextData, instance: *Instance) void {
    const owned = hooks orelse return;
    if (!realm.hasEngine()) return;
    const list = &realm.orphan_roots;
    if (list.ended) return;
    // A full list first drops what is no longer an orphan - a root moved
    // into a tree (the fragment insertion and parser moves that remove a
    // node only to insert it), wrapped or freed since - so it stays in
    // proportion to the realm's orphans, not its removals.
    if (list.records.items.len == list.records.capacity and list.records.items.len >= List.compact_threshold) {
        var kept: usize = 0;
        for (list.records.items) |entry| {
            if (!stillOrphan(entry, owned)) continue;
            list.records.items[kept] = entry;
            kept += 1;
        }
        list.records.shrinkRetainingCapacity(kept);
    }
    list.records.append(realm.allocator, .{ .instance = instance, .generation = SlabAllocator.generationOf(instance) }) catch return;
}

/// `realm` ends: free each recorded root that is still an orphan, before
/// anything of the realm is torn down. Nothing is recorded after.
pub fn drain(realm: *ContextData) void {
    const list = &realm.orphan_roots;
    list.ended = true;
    const owned = hooks orelse {
        list.records.clearAndFree(realm.allocator);
        return;
    };
    // A teardown may remove nodes (and finds the list ended): take the
    // records first.
    var records = list.records;
    list.records = .empty;
    defer records.deinit(realm.allocator);
    for (records.items) |entry| {
        if (!stillOrphan(entry, owned)) continue;
        owned.free(entry.instance);
    }
}
