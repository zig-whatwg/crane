//! Node holds: native references to nodes that keep them alive without a
//! wrapper per node, for any holder - a MutationRecord, a static NodeList, a
//! live parser.
//!
//! Blink keeps such nodes with a traced `Member<Node>` (MutationRecord's
//! target_ and siblings, StaticNodeList's HeapVector<Member<Node>>,
//! HTMLConstructionSite's open elements) and WebKit with a `Ref<Node>`; both
//! make a wrapper only when script asks for the node. Crane has no tracing of
//! native objects, and tracing each node from the holder's wrapper wraps
//! every node the moment the holder is filled
//! (docs/lessons/architecture-tracing-a-holders-nodes-makes-a-wrapper-per-node.md).
//! Two facts of Crane's collector make a native hold enough
//! (tests/v8/parser_holds_invariants_test.zig pins both):
//!
//! - L1: the collector frees a node only as the root of its tree, or inside a
//!   freed root's subtree (`wrapper_cache.treeOwns`).
//! - L2: wrappers in a tree are upward-closed and linked both ways, so a
//!   rooted wrapper anywhere in a tree keeps the tree's root and every wrapper
//!   in it.
//!
//! So a held node is safe while its host-including root is a Document the host
//! keeps - one with a default view, whose window holds its wrapper strongly
//! (`isKeptRoot`) - or a node whose wrapper the HOLDER rooted. Every other
//! root is RESCUED: one wrapper, rooted from the holder, never one per node.
//! A held node leaves a kept tree only by a removal, so the removing steps -
//! one callback, installed at process start - hear every way it can happen.
//!
//! Two kinds of holder:
//!
//! - **Marked holds** (`Holder`, `Hold`): each held node carries the head of
//!   a chain of the holds on it (`NodeBase.holds`). A removal pays one field
//!   test per node it visits when nothing in the subtree is held, and when
//!   something is, the chain names exactly the holders to ask.
//! - **Scanning holders** (`Registry`): a holder whose held set changes too
//!   often to mark - a parser's stack of open elements - registers with its
//!   Browser, and is asked on each removal ROOT whether that root contains a
//!   node it holds (pholds' O(stack depth) walk).
//!
//! A rescue is an edge from the holder's wrapper to the root's
//! (engine.traceChild into "node-holds:root", then a dense array traced in
//! "node-holds:roots"), never a root of its own: a holder and a tree that
//! reach each other still collect together. A holder script has not seen yet
//! (a record still queued) holds its edges strongly in its realm's wrapper
//! cache until it is wrapped, and lets them go in its teardown
//! (forgetTracedChild) when it is freed unwrapped.
//!
//! Design: tmp/plans/lane-nodeholds-handoff.md; the parser's half,
//! tmp/plans/parser-holds-design.md and
//! docs/lessons/architecture-parser-holds-are-its-structures-and-detached-trees-are-rescued.md.

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.node_holds);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");
const template_contents = @import("template_contents.zig");

/// One holder's hold on one node: a link in the node's chain
/// (`NodeBase.holds`). Embedded by its holder and never moved while linked.
pub const Hold = struct {
    /// The held node; null when this hold holds nothing (released, or a null
    /// member such as a record's absent sibling).
    node: ?*runtime.Instance = null,
    /// The node's slab generation when it was held. A node freed outside the
    /// collector (its realm's end, `clearChildren`, a fragment's explicit
    /// teardown) reads dead here: its chain is gone with its storage, and
    /// every hold in it is skipped the same way, never walked.
    generation: u64 = 0,
    base: *NodeBase = undefined,
    holder: *Holder = undefined,
    prev: ?*Hold = null,
    next: ?*Hold = null,

    /// The held node, or null when it was freed outside the collector - a
    /// teardown net, never the behaviour: the hold is what keeps it.
    pub fn get(self: *const Hold) ?*runtime.Instance {
        const node = self.node orelse return null;
        if (!stillHeld(node, self.generation)) return null;
        return node;
    }

    /// Whether `node` is still the node held at `generation`. A teardown can
    /// free a node's NodeBase and leave its slab slot - and generation - live
    /// (coordinated teardown, a wrapper still cached), so the generation
    /// alone cannot say; `nodeReleased` nulls the hold first, and this check
    /// covers a slot freed and reissued.
    fn stillHeld(node: *runtime.Instance, generation: u64) bool {
        return runtime.SlabAllocator.generationOf(node) == generation;
    }

    fn link(self: *Hold, holder: *Holder, node: *runtime.Instance, base: *NodeBase) void {
        self.* = .{
            .node = node,
            .generation = runtime.SlabAllocator.generationOf(node),
            .base = base,
            .holder = holder,
            .prev = null,
            .next = base.holds,
        };
        if (base.holds) |head| head.prev = self;
        base.holds = self;
    }

    fn unlink(self: *Hold) void {
        const node = self.node orelse return;
        self.node = null;
        // A dead node's chain is never walked again: leave it.
        if (!stillHeld(node, self.generation)) return;
        if (self.prev) |prev| prev.next = self.next else self.base.holds = self.next;
        if (self.next) |next| next.prev = self.prev;
        self.prev = null;
        self.next = null;
    }
};

/// `node`'s storage is going (Node.deinit and the final registry sweep,
/// beside the release of its registered observers, just before its NodeBase
/// is freed): every hold on it now holds nothing. Its holders read null from
/// then on and skip it when they let go - a teardown net for the ways a node
/// is freed outside the collector (its realm's coordinated teardown, the
/// final registry sweep), where its slab generation can stay live.
///
/// Touches only the native hold records - no engine call, no allocation - so
/// it may run inside any teardown, including one a collector's finalizer
/// path started.
pub fn nodeReleased(node: *NodeBase) void {
    var current = node.holds;
    node.holds = null;
    while (current) |held| {
        current = held.next;
        held.node = null;
        held.prev = null;
        held.next = null;
    }
}

/// The edge slots a holder's rescues hang from, on its owner's wrapper.
pub const root_slot: engine.TracedSlot = .{ .name = "node-holds:root" };
pub const roots_slot: engine.TracedSlot = .{ .name = "node-holds:roots" };

/// Below this many rescues a holder never prunes them.
const min_prune = 64;

/// A holder of marked holds, embedded in its owner's state: a MutationRecord,
/// a static NodeList.
pub const Holder = struct {
    /// What the holds and rescues are allocated with.
    allocator: Allocator,
    /// Whose wrapper the rescues hang from: the holder's own instance.
    owner: *runtime.Instance,
    owner_generation: u64,
    /// The holds, in the holder's own order; owned.
    holds: []Hold = &.{},
    rescues: Rescues = .{},
    /// Rescues that make a prune (see `maybePrune`).
    prune_at: usize = min_prune,

    pub fn init(allocator: Allocator, owner: *runtime.Instance) Holder {
        return .{ .allocator = allocator, .owner = owner, .owner_generation = runtime.SlabAllocator.generationOf(owner) };
    }

    /// Hold `nodes`, in order (`T` is `*runtime.Instance` or
    /// `?*runtime.Instance`; a null holds nothing), then rescue every root of
    /// theirs that is not a kept document. `root_hint`: the host-including
    /// root they all share, when the caller knows it (querySelectorAll's
    /// receiver's), so it is found once. The holder holds nothing yet.
    pub fn hold(self: *Holder, comptime T: type, nodes: []const T, root_hint: ?*NodeBase) Allocator.Error!void {
        std.debug.assert(self.holds.len == 0);
        if (nodes.len == 0) return;
        const holds = try self.allocator.alloc(Hold, nodes.len);
        for (nodes, holds) |maybe, *slot| {
            slot.* = .{};
            const node: *runtime.Instance = if (T == ?*runtime.Instance) (maybe orelse continue) else maybe;
            const base = instance_bridge.getNodeBase(@ptrCast(node)) orelse continue;
            slot.link(self, node, base);
        }
        self.holds = holds;
        self.rescueUnkeptRoots(root_hint);
    }

    /// The node of hold `index` (see `Hold.get`).
    pub fn get(self: *const Holder, index: usize) ?*runtime.Instance {
        if (index >= self.holds.len) return null;
        return self.holds[index].get();
    }

    /// Let every node go, and every rescue: the holder is cleared or going.
    /// Safe in any teardown (4.12: a teardown may end traced edges); makes no
    /// engine call unless the holder rescued something.
    pub fn release(self: *Holder) void {
        const allocator = self.allocator;
        for (self.holds) |*held| held.unlink();
        if (self.holds.len != 0) allocator.free(self.holds);
        self.holds = &.{};
        if (self.rescues.made()) {
            engine.forgetTracedChild(self.owner, root_slot);
            engine.forgetTracedChild(self.owner, roots_slot);
        }
        self.rescues.deinit(allocator);
        self.rescues = .{};
        self.prune_at = min_prune;
    }

    /// Rescue the root of every held node whose tree is not a kept document.
    fn rescueUnkeptRoots(self: *Holder, root_hint: ?*NodeBase) void {
        if (!self.owner.ctx.hasEngine()) return;
        var memo: RootMemo = .{};
        var last_root: ?*NodeBase = null;
        for (self.holds) |*held| {
            if (held.node == null) continue;
            const root = root_hint orelse memo.rootOf(held.base);
            if (root == last_root) continue;
            last_root = root;
            if (isKeptRoot(root)) continue;
            if (!self.rescue(root)) return;
        }
    }

    /// Rescue(holder, R): root `root`'s wrapper from this holder's until it
    /// is released - one wrapper at most, never one per node. Whether the
    /// holder is still there afterwards (engine work can tear down objects).
    pub fn rescue(self: *Holder, root: *NodeBase) bool {
        const root_instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(root) orelse return true));
        const generation = runtime.SlabAllocator.generationOf(root_instance);
        if (self.rescues.contains(root_instance, generation)) return true;
        if (!root_instance.ctx.hasEngine() or !self.owner.ctx.hasEngine()) return true;
        const allocator = self.allocator;
        self.rescues.entries.ensureUnusedCapacity(allocator, 1) catch return true;
        const owner = self.owner;
        const owner_generation = self.owner_generation;
        const index: usize = if (!self.rescues.single_taken) blk: {
            // The first rescue: one edge, one call.
            self.rescues.single_taken = true;
            engine.traceChild(owner, root_instance, root_slot);
            break :blk single_index;
        } else blk: {
            const index = self.rescues.next_index;
            self.rescues.next_index += 1;
            putRoot(owner, roots_slot, index, root_instance) catch |err| {
                log.warn("node hold rescue failed: {}", .{err});
                return runtime.SlabAllocator.generationOf(owner) == owner_generation;
            };
            break :blk index;
        };
        if (runtime.SlabAllocator.generationOf(owner) != owner_generation) return false;
        self.rescues.append(allocator, .{ .node = root_instance, .base = root, .generation = generation, .index = index });
        self.maybePrune();
        return true;
    }

    /// A long-lived holder whose nodes move through many trees would keep
    /// every tree it ever rescued. Once its rescues reach `prune_at`, drop
    /// each whose tree holds none of its nodes any more, or is now a kept
    /// document's (a rescue inside a tree script moved elsewhere stays: by L2
    /// it keeps the tree it is in, which holds the node). `prune_at` then
    /// doubles over what is kept, and never falls below a quarter of the
    /// holds, so a large list that rescues many trees at once does not prune
    /// on every one.
    fn maybePrune(self: *Holder) void {
        if (self.rescues.entries.items.len < self.prune_at) return;
        const allocator = self.allocator;
        var needed: std.AutoHashMapUnmanaged(*NodeBase, void) = .empty;
        defer needed.deinit(allocator);
        var memo: RootMemo = .{};
        for (self.holds) |*held| {
            if (held.get() == null) continue;
            const root = memo.rootOf(held.base);
            if (isKeptRoot(root)) continue;
            needed.put(allocator, root, {}) catch return;
        }
        var kept: usize = 0;
        for (self.rescues.entries.items) |entry| {
            const alive = runtime.SlabAllocator.generationOf(entry.node) == entry.generation;
            if (alive and needed.contains(hostIncludingRoot(entry.base))) {
                self.rescues.entries.items[kept] = entry;
                kept += 1;
                continue;
            }
            self.dropRescue(entry);
        }
        self.rescues.entries.shrinkRetainingCapacity(kept);
        self.rescues.reindex(allocator);
        self.prune_at = @max(min_prune, 2 * kept, self.holds.len / 4);
    }

    fn dropRescue(self: *Holder, entry: Rescues.Entry) void {
        if (entry.index == single_index) {
            engine.forgetTracedChild(self.owner, root_slot);
            self.rescues.single_taken = false;
            return;
        }
        clearRoot(self.owner, roots_slot, entry.index);
    }
};

/// The index a holder's first rescue takes: its own slot, not the array.
const single_index = std.math.maxInt(usize);

/// The roots a holder rescued, deduplicated.
pub const Rescues = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    /// Membership, once there are enough entries for a scan to cost.
    index: std.AutoHashMapUnmanaged(*runtime.Instance, u64) = .empty,
    single_taken: bool = false,
    next_index: usize = 0,

    pub const Entry = struct {
        node: *runtime.Instance,
        base: *NodeBase,
        generation: u64,
        /// Its index in the owner's container, or `single_index`.
        index: usize,
    };

    const index_from = 16;

    fn made(self: *const Rescues) bool {
        return self.single_taken or self.next_index != 0;
    }

    pub fn contains(self: *const Rescues, node: *runtime.Instance, generation: u64) bool {
        const items = self.entries.items;
        if (items.len == 0) return false;
        // Consecutive held nodes of one removal share their root.
        const last = items[items.len - 1];
        if (last.node == node and last.generation == generation) return true;
        if (items.len > index_from) {
            const found = self.index.get(node) orelse return false;
            return found == generation;
        }
        for (items) |entry| {
            if (entry.node == node and entry.generation == generation) return true;
        }
        return false;
    }

    fn append(self: *Rescues, allocator: Allocator, entry: Entry) void {
        self.entries.appendAssumeCapacity(entry);
        if (self.entries.items.len > index_from) {
            if (self.entries.items.len == index_from + 1) {
                self.reindex(allocator);
            } else {
                self.index.put(allocator, entry.node, entry.generation) catch {};
            }
        }
    }

    fn reindex(self: *Rescues, allocator: Allocator) void {
        self.index.clearRetainingCapacity();
        if (self.entries.items.len <= index_from) return;
        for (self.entries.items) |entry| self.index.put(allocator, entry.node, entry.generation) catch {};
    }

    pub fn deinit(self: *Rescues, allocator: Allocator) void {
        self.entries.deinit(allocator);
        self.index.deinit(allocator);
    }
};

/// The dense array `owner` keeps in `slot`, OWNED: made on first use and
/// published as a traced value, verified by reading it back while the
/// constructor's hold still roots it.
pub fn container(owner: *runtime.Instance, slot: engine.TracedSlot) !engine.Owned {
    if (engine.tracedValue(owner, slot)) |existing| return existing;
    const made = try engine.createSequenceOfValues(owner.ctx, &.{});
    errdefer made.release();
    engine.traceValue(owner, made.borrow(), slot);
    const published = engine.tracedValue(owner, slot) orelse {
        engine.forgetTracedChild(owner, slot);
        return error.OutOfMemory;
    };
    defer published.release();
    if (!engine.sameValue(owner.ctx, made.borrow(), published.borrow())) {
        engine.forgetTracedChild(owner, slot);
        return error.InvalidStateError;
    }
    return made;
}

/// Root `root`'s wrapper - made if it has none, in its relevant realm - at
/// `index` of the container `owner` keeps in `slot`: a dense numeric own
/// property, so no prototype setter runs. One engine step makes the wrapper
/// and stores it.
pub fn putRoot(owner: *runtime.Instance, slot: engine.TracedSlot, index: usize, root: *runtime.Instance) !void {
    const array = try container(owner, slot);
    defer array.release();
    var buffer: [32]u8 = undefined;
    const key = std.fmt.bufPrint(&buffer, "{d}", .{index}) catch unreachable;
    try engine.defineOwnProperty(owner.ctx, array.borrow(), key, .{ .instance = root }, .{
        .writable = true,
        .enumerable = true,
        .configurable = true,
    });
}

/// Let the root at `index` of `owner`'s container in `slot` go.
pub fn clearRoot(owner: *runtime.Instance, slot: engine.TracedSlot, index: usize) void {
    const array = engine.tracedValue(owner, slot) orelse return;
    defer array.release();
    var buffer: [32]u8 = undefined;
    const key = std.fmt.bufPrint(&buffer, "{d}", .{index}) catch unreachable;
    engine.defineOwnProperty(owner.ctx, array.borrow(), key, .undefined, .{
        .writable = true,
        .enumerable = true,
        .configurable = true,
    }) catch {};
}

/// Whether `root` - the host-including root of a held node's tree - is kept
/// by the host whatever its wrapper does: a Document with a default view
/// (its window holds its wrapper strongly - wrapper_cache.engineHoldsWrapper
/// - as Blink's LocalDOMWindow traces document_). The default is false: any
/// other root is rescued.
pub fn isKeptRoot(root: *NodeBase) bool {
    if (root.node_type != NodeBase.DOCUMENT_NODE) return false;
    const opaque_instance = instance_bridge.getInstance(root) orelse return false;
    const document: *runtime.Instance = @ptrCast(@alignCast(opaque_instance));
    const view = interfaces.Document.get_defaultView(document) catch return false;
    return view != null;
}

/// The root of `node`'s host-including tree: the root of its tree, or - when
/// that root is a fragment with a host (a template's contents, a shadow root)
/// - the host-including root of the host.
pub fn hostIncludingRoot(node: *NodeBase) *NodeBase {
    var current = node;
    while (true) {
        if (current.parent_node) |parent| {
            current = parent;
            continue;
        }
        current = hostOfRoot(current) orelse return current;
    }
}

/// Whether `root` - a parentless node - is a host-including inclusive
/// ancestor of `node` (DOM: "either A is an inclusive ancestor of B, or B's
/// root has a non-null host and A is a host-including inclusive ancestor of
/// B's root's host"). The walk stops early at `known_outside`, a node already
/// known not to be under `root`.
pub fn isUnderRoot(node: *NodeBase, root: *NodeBase, known_outside: ?*NodeBase) bool {
    var current = node;
    while (true) {
        if (current == root) return true;
        if (known_outside) |outside| if (current == outside) return false;
        if (current.parent_node) |parent| {
            current = parent;
            continue;
        }
        current = hostOfRoot(current) orelse return false;
    }
}

/// The host of a parentless fragment - a template's contents or a shadow
/// root - or null.
fn hostOfRoot(root: *NodeBase) ?*NodeBase {
    if (root.node_type != NodeBase.DOCUMENT_FRAGMENT_NODE) return null;
    const opaque_instance = instance_bridge.getInstance(root) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(opaque_instance));
    if (template_contents.host(instance)) |host| return instance_bridge.getNodeBase(@ptrCast(host));
    if (isShadowRoot(root)) {
        const host = interfaces.ShadowRoot.get_host(instance) catch return null;
        return instance_bridge.getNodeBase(@ptrCast(host));
    }
    return null;
}

fn isShadowRoot(node: *NodeBase) bool {
    if (node.node_type != NodeBase.DOCUMENT_FRAGMENT_NODE) return false;
    const opaque_instance = instance_bridge.getInstance(node) orelse return false;
    const instance: *runtime.Instance = @ptrCast(@alignCast(opaque_instance));
    return instance.stateAs(interfaces.ShadowRoot.State) != null;
}

/// Roots of nodes visited in tree order: a node whose parent is the last
/// node's parent, or the last node itself, shares its root.
const RootMemo = struct {
    last_node: ?*NodeBase = null,
    last_parent: ?*NodeBase = null,
    last_root: ?*NodeBase = null,

    fn rootOf(self: *RootMemo, node: *NodeBase) *NodeBase {
        const parent = node.parent_node;
        const root = blk: {
            if (self.last_root) |known| {
                if (parent != null and (parent == self.last_parent or parent == self.last_node)) break :blk known;
            }
            break :blk hostIncludingRoot(node);
        };
        self.last_node = node;
        self.last_parent = parent;
        self.last_root = root;
        return root;
    }
};

// ============================================================================
// Scanning holders
// ============================================================================

/// A holder whose held set changes too often to mark - a live parser's stack
/// of open elements, which changes on every push and pop. The removing steps
/// ask it on each removal root.
pub const Scanner = struct {
    context: *anyopaque,
    /// Whether `root` - left parentless by a removal - is a host-including
    /// inclusive ancestor of a node this holder holds. Reads only.
    holds_node_under: *const fn (context: *anyopaque, root: *NodeBase) bool,
    /// Rescue `root`. May make wrappers and run engine work.
    rescue: *const fn (context: *anyopaque, root: *runtime.Instance) void,
    /// Keep the holder alive across its rescue.
    retain: *const fn (context: *anyopaque) void,
    release: *const fn (context: *anyopaque) void,
    /// The owner of the container its rescues share with other scanners
    /// (a parser's Document), with its generation, and where this scanner
    /// records one past the highest index it reserved there.
    container_owner: *runtime.Instance,
    container_generation: u64,
    slot_end: *usize,
};

/// A Browser's scanning holders: a supplement of its scope
/// (runtime.BrowserScope, docs/instances.md rule 2), reached through the
/// realm of the node a removal detaches.
///
/// The DOM and its parsers live on the Browser's window agent thread: every
/// registration, every walk and every rescue happens there. The mutex guards
/// the list as a supplement must, and is never held across a rescue, which
/// makes wrappers and may let the collector finalize objects.
pub const Registry = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    scanners: std.ArrayListUnmanaged(Scanner) = .empty,

    pub fn init(allocator: Allocator) Registry {
        return .{ .allocator = allocator };
    }

    /// The scope's end. A scanner still registered outlives the Browser's
    /// scope only by leaking.
    pub fn deinit(self: *Registry) void {
        self.scanners.deinit(self.allocator);
    }

    /// The registry of the Browser `realm` belongs to, made on first use;
    /// null for a realm with no Browser scope (a test realm).
    pub fn of(realm: runtime.Context) ?*Registry {
        const scope = realm.browser_scope orelse return null;
        return scope.of(Registry) catch null;
    }

    /// The registry of the Browser `realm` belongs to, if one was made.
    pub fn existingOf(realm: runtime.Context) ?*Registry {
        const scope = realm.browser_scope orelse return null;
        return scope.existing(Registry);
    }

    pub fn register(self: *Registry, scanner: Scanner) Allocator.Error!void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        try self.scanners.append(self.allocator, scanner);
    }

    pub fn unregister(self: *Registry, context: *anyopaque) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.scanners.items, 0..) |registered, i| {
            if (registered.context != context) continue;
            _ = self.scanners.orderedRemove(i);
            return;
        }
    }

    /// Reserve the next index of the container `context`'s rescues share
    /// with every registered scanner of the same container owner: one past
    /// the highest any of them reserved. A scanner clears its slots before it
    /// unregisters, so no live scanner's slot is ever reused. Reserved before
    /// any engine allocation: a rescue that reenters cannot take the same
    /// index.
    pub fn reserveIndex(self: *Registry, context: *anyopaque) ?usize {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const mine = for (self.scanners.items) |scanner| {
            if (scanner.context == context) break scanner;
        } else return null;
        var next = mine.slot_end.*;
        for (self.scanners.items) |other| {
            if (other.container_owner != mine.container_owner or other.container_generation != mine.container_generation) continue;
            next = @max(next, other.slot_end.*);
        }
        mine.slot_end.* = next + 1;
        return next;
    }

    fn hasScanners(self: *Registry) bool {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.scanners.items.len != 0;
    }

    /// The removing steps' question to every scanner: does `root` contain a
    /// node you hold? Each that does rescues `root`. The walks only read; the
    /// rescues run after the lock is released, each scanner retained across
    /// its own.
    fn rescueTreesContaining(self: *Registry, root: *runtime.Instance, root_base: *NodeBase) void {
        var start: usize = 0;
        while (true) {
            var batch: [8]Scanner = undefined;
            var count: usize = 0;
            var done = true;
            {
                std.Io.Threaded.mutexLock(&self.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.mutex);
                var i = start;
                while (i < self.scanners.items.len) : (i += 1) {
                    if (count == batch.len) {
                        done = false;
                        break;
                    }
                    const scanner = self.scanners.items[i];
                    if (!scanner.holds_node_under(scanner.context, root_base)) continue;
                    scanner.retain(scanner.context);
                    batch[count] = scanner;
                    count += 1;
                }
                start = i;
            }
            for (batch[0..count]) |scanner| {
                scanner.rescue(scanner.context, root);
                scanner.release(scanner.context);
            }
            if (done) return;
        }
    }
};

// ============================================================================
// The removing steps
// ============================================================================

/// Installed once, at process start, by each owner of holds (NodeList,
/// MutationRecord, the HTML parser; docs/instances.md "Hooks"). The callback
/// list it joins is dom.mutation's own, which takes a function once.
pub fn installHooks() void {
    @import("mutation.zig").registerRemovingStepsCallback(onRemovingSteps) catch {};
}

/// DOM "removing steps", for the removal root (remove step 11) and each of
/// its shadow-including descendants (step 14).
fn onRemovingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.holds != null) rescueForHolds(node);
    // The scanners are asked about the removal root only: a descendant still
    // has its parent; a shadow root, the other parentless node step 14
    // visits, is inside the removed tree through its host.
    if (node.parent_node != null) return;
    if (isShadowRoot(node)) return;
    const opaque_instance = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(opaque_instance));
    const registry = Registry.existingOf(instance.ctx) orelse return;
    if (!registry.hasScanners()) return;
    registry.rescueTreesContaining(instance, node);
}

/// `node`, in a subtree a removal just detached, is held: every holder of it
/// rescues the subtree's root. The chain is copied first, with each holder's
/// owner generation, so a holder that engine work tears down during an
/// earlier rescue is skipped rather than reached.
fn rescueForHolds(node: *NodeBase) void {
    const root = hostIncludingRoot(node);
    if (isKeptRoot(root)) return;
    const Entry = struct { holder: *Holder, owner: *runtime.Instance, generation: u64 };
    var stack_entries: [16]Entry = undefined;
    var heap_entries: std.ArrayListUnmanaged(Entry) = .empty;
    const allocator = node.allocator;
    defer heap_entries.deinit(allocator);
    var count: usize = 0;
    var current = node.holds;
    while (current) |held| : (current = held.next) {
        const entry: Entry = .{ .holder = held.holder, .owner = held.holder.owner, .generation = held.holder.owner_generation };
        if (count < stack_entries.len) {
            stack_entries[count] = entry;
        } else {
            if (count == stack_entries.len) heap_entries.appendSlice(allocator, &stack_entries) catch return;
            heap_entries.append(allocator, entry) catch return;
        }
        count += 1;
    }
    const entries = if (count <= stack_entries.len) stack_entries[0..count] else heap_entries.items;
    for (entries) |entry| {
        if (runtime.SlabAllocator.generationOf(entry.owner) != entry.generation) continue;
        _ = entry.holder.rescue(root);
    }
}
