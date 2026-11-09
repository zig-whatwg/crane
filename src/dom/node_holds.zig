//! Node holds: native references to nodes that keep them alive without a
//! wrapper per node, for any holder - a MutationRecord, a static NodeList, a
//! live collection's root, a queued task.
//!
//! Every hold is a COUNTED reference on its node (`refcount.holderRef`;
//! refcount step 5): WebKit's holders keep a `Ref<Node>` (ChildListRecord,
//! StaticNodeList, RangeBoundaryPoint), and since refcount step 7 the counts
//! decide every free - a held node is never freed under its hold during its
//! realm's life.
//!
//! What a holder holds FOR SCRIPT - a node script can read back from it - it
//! also names to the engine's collector, so the holder's wrapper keeps the
//! held nodes' wrappers and their trees' (the wrapper redesign's P6,
//! tmp/redesign/wrapper-redesign-design.md 3.2 rule (d) and 4.4
//! "Holders"; refcount step 9b): the holder's type declares `pub fn
//! traceHeldNodes(instance, tracer)` on its InternalState
//! (runtime.lifetime.heldNodesOf puts it in its VTable), which calls `trace`
//! on its holds, and `trace` asks the walk (dom.wrapper_tracing.traceHeld)
//! for each node: its own wrapper and every wrapper of its host-including
//! tree and its node document's tree. It runs in the collector's atomic
//! pause, so it only reads. No wrapper is made for a held node - the cost
//! lesson docs/lessons/architecture-tracing-a-holders-nodes-makes-a-
//! wrapper-per-node.md: the trace names the wrappers that exist. Blink's
//! holders trace their `Member<Node>`s the same way (Chromium 131.0.6778.0:
//! StaticNodeTypeList::Trace `nodes_`, ChildListRecord::Trace `target_` and
//! siblings, IntersectionObserverEntry::Trace `target_`, XPathResult::Trace
//! `node_set_` and `document_`, HTMLConstructionSite::Trace `open_elements_`,
//! `active_formatting_elements_`, `head_` and `form_`).
//!
//! Until the redesign's P7 the V8 adapter also keeps the holders' JS edges
//! (engine.keepOpaqueRoot, called only while the engine's wrapper tracing
//! is `.emulated`): `MemberHold` draws one. The node holds' chain on each
//! node (`NodeBase.holds`), its rescues of detached roots, the scanning
//! holders' registry and the removing-steps callback that asked them are
//! gone with P6 - tracing finds a held node wherever its tree went.
//!
//! A node freed under its hold - only a forced realm end's coordinated
//! teardown or the Browser's final sweep frees a node whatever the counts
//! say - is recognised the way the wrapper's own reference recognises one:
//! its slab slot freed or reissued (the generation), or its teardown begun
//! (`instance_lifecycle.isCleanupStarted`: Node.deinit, and the final
//! sweep's release of the NodeBase, mark it). Its reference is then
//! FORGOTTEN, never released. The slab outlives every node of its Browser,
//! so the check reads nothing freed; a hold must not outlive its node's
//! Browser.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.node_holds);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");
const template_contents = @import("template_contents.zig");
const refcount = @import("refcount.zig");
const wrapper_tracing = @import("wrapper_tracing.zig");

/// One hold on one node: one counted reference on it (`refcount.holderRef`)
/// for as long as it holds it. No link: it may move while it holds - only
/// its holder names it.
pub const Hold = struct {
    /// The held node; null when this hold holds nothing (released, or a null
    /// member such as a record's absent sibling).
    node: ?*runtime.Instance = null,
    /// The node's slab generation when it was held.
    generation: u64 = 0,
    base: *NodeBase = undefined,

    /// The held node, or null when it was freed outside the collector - a
    /// teardown net, never the behaviour: the hold is what keeps it.
    pub fn get(self: *const Hold) ?*runtime.Instance {
        const node = self.node orelse return null;
        if (!stillHeld(node, self.generation)) return null;
        return node;
    }

    /// Whether `node` is still the node held at `generation`: its slot not
    /// freed or reissued, and its teardown not begun - a forced realm end's
    /// coordinated teardown (Node.deinit) or the final sweep can release a
    /// node's NodeBase while its slab slot, and its generation, stay live.
    fn stillHeld(node: *runtime.Instance, generation: u64) bool {
        if (runtime.SlabAllocator.generationOf(node) != generation) return false;
        return !runtime.instance_lifecycle.isCleanupStarted(node);
    }

    fn link(self: *Hold, node: *runtime.Instance, base: *NodeBase) void {
        self.* = .{
            .node = node,
            .generation = runtime.SlabAllocator.generationOf(node),
            .base = base,
        };
        refcount.holderRef(base);
    }

    fn unlink(self: *Hold) void {
        const node = self.node orelse return;
        self.node = null;
        // A node freed under it took its reference with it: forgotten.
        if (!stillHeld(node, self.generation)) return;
        refcount.holderDeref(self.base);
    }

    /// The collector's pause (a holder's `traceHeldNodes`): the held node's
    /// wrapper and every wrapper of its trees are kept (design 3.2 (d)).
    /// Reads only.
    pub fn trace(self: *const Hold, tracer: *engine.Tracer) void {
        _ = self.get() orelse return;
        wrapper_tracing.traceHeld(self.base, tracer);
    }
};

/// `owner`'s wrapper keeps `member` while the engine keeps node tracing's
/// edges (`.emulated` wrapper tracing: V8 until the redesign's P7; the
/// JavaScriptCore public-API path, design 5.2): engine.keepOpaqueRoot, an
/// edge to `member`'s own wrapper, else to its tree's wrapped root. Makes no
/// wrapper - the holder's trace keeps what an edge cannot reach (P6 deleted
/// the wrap-first net). A member that is not a node is kept as
/// engine.traceChild keeps it, whatever the engine. Whether a keep was
/// taken (the slot may hold an edge to forget).
fn keepMemberOf(owner: *runtime.Instance, member: *runtime.Instance, is_node: bool, slot: engine.TracedSlot) bool {
    if (!owner.ctx.hasEngine() or !member.ctx.hasEngine()) return false;
    if (is_node and engine.capabilities.wrapper_tracing != .emulated) return false;
    engine.keepOpaqueRoot(owner, member, slot);
    return true;
}

/// One node a holder holds and keeps for script: a live collection's root
/// (refcount design 5h; WebKit's collections hold `Ref<ContainerNode>
/// m_ownerNode`), an entry's target, a saved focus. A counted hold, traced
/// by its owner's `traceHeldNodes` (`trace`), plus - while the engine keeps
/// node edges - the owner's keep of the member's opaque root. A member that
/// is not a node (a collection that roots a RadioNodeList) is kept, not
/// counted.
pub const MemberHold = struct {
    hold: Hold = .{},
    /// The member when it is not a node (kept, not counted), with its
    /// generation; a node member is the hold's.
    other: ?*runtime.Instance = null,
    other_generation: u64 = 0,
    kept: bool = false,

    /// Hold `member` from `owner` and keep its opaque root in `slot`. The
    /// member hold holds nothing yet.
    pub fn take(self: *MemberHold, owner: *runtime.Instance, member: *runtime.Instance, slot: engine.TracedSlot) void {
        std.debug.assert(self.hold.node == null and self.other == null);
        const base = instance_bridge.getNodeBase(@ptrCast(member));
        if (base) |node| {
            self.hold.link(member, node);
        } else {
            self.other = member;
            self.other_generation = runtime.SlabAllocator.generationOf(member);
        }
        self.kept = keepMemberOf(owner, member, base != null, slot);
    }

    /// The member's tree node while it is alive and a node; null otherwise.
    pub fn liveBase(self: *const MemberHold) ?*NodeBase {
        _ = self.hold.get() orelse return null;
        return self.hold.base;
    }

    /// The member, or null once it was freed (a teardown net).
    pub fn get(self: *const MemberHold) ?*runtime.Instance {
        if (self.other) |member| {
            if (runtime.SlabAllocator.generationOf(member) != self.other_generation) return null;
            return member;
        }
        return self.hold.get();
    }

    /// Let the member go, and the keep: the owner is cleared or going.
    pub fn release(self: *MemberHold, owner: *runtime.Instance, slot: engine.TracedSlot) void {
        self.hold.unlink();
        self.other = null;
        if (self.kept) engine.forgetTracedChild(owner, slot);
        self.kept = false;
    }

    /// The collector's pause: the member node's wrappers (`Hold.trace`). A
    /// member that is not a node is kept by its edge.
    pub fn trace(self: *const MemberHold, tracer: *engine.Tracer) void {
        self.hold.trace(tracer);
    }
};

// ============================================================================
// Counted references: a holder's Ref(Node)
// ============================================================================

/// One node a holder names, held by one counted reference and nothing more:
/// the refcount design's `Ref(T)` / `?Ref(T)` (section 1.6) in shadow mode,
/// for a holder that already keeps the node for script some other way - an
/// edge from its wrapper (engine.traceChild), a pin - and keeps that way
/// until refcount step 9b deletes it. WebKit's holders keep these as plain
/// members: RangeBoundaryPoint `Ref<Node> m_container`
/// (Source/WebCore/dom/RangeBoundaryPoint.h), NodeIteratorBase `const
/// Ref<Node> m_root` (dom/Traversal.h), TreeWalker `Ref<Node> m_current`
/// (dom/TreeWalker.h), Event `RefPtr<EventTarget> m_target` (dom/Event.h),
/// EventContext `RefPtr<Node> m_node` (dom/EventContext.h).
///
/// A `Hold`: one `refcount.holderRef` while it holds the node. A node freed
/// under it - its realm's forced end, the final sweep - is FORGOTTEN, never
/// released (`Hold.stillHeld`), so a later `set` or `release` writes nothing
/// to the freed node. A member that is not a node (a Window, an
/// XMLHttpRequest) is not counted - decision D3, nodes first - and this
/// holds nothing for it.
///
/// Let go once, at the holder's end (`release` on one never taken, or
/// again, does nothing).
pub const RefHold = struct {
    hold: Hold = .{},

    /// Hold `member` - or nothing, for null - and let go of what this held.
    /// Holding the node it holds already changes nothing.
    pub fn set(self: *RefHold, member: ?*runtime.Instance) void {
        const target = member orelse return self.hold.unlink();
        if (self.holds(target)) return;
        self.hold.unlink();
        const base = instance_bridge.getNodeBase(@ptrCast(target)) orelse return;
        self.hold.link(target, base);
    }

    /// `set` for a caller that has `member`'s tree node already: `base`, or
    /// null when `member` is not a node.
    pub fn setNode(self: *RefHold, member: *runtime.Instance, base: ?*NodeBase) void {
        if (self.holds(member)) return;
        self.hold.unlink();
        self.hold.link(member, base orelse return);
    }

    /// Whether this holds `member` now: taken on it, at the slab generation
    /// it was held at.
    pub fn holds(self: *const RefHold, member: *runtime.Instance) bool {
        return self.hold.node == member and Hold.stillHeld(member, self.hold.generation);
    }

    /// Let the node go. Safe on a hold never taken, and to repeat.
    pub fn release(self: *RefHold) void {
        self.hold.unlink();
    }
};

/// A counted reference for a holder that has the node's tree node at hand
/// and lives a short, bounded time - the items of an event's path while
/// dispatch runs: WebKit's EventContext `RefPtr<Node> m_node`. A node freed
/// under it is recognised the way the wrapper's own reference recognises one
/// (wrapper_cache `releaseCounted`): its slot reissued, or its teardown
/// begun - and then it is forgotten, never released. 16 bytes. Counted
/// only: since step 7 the count keeps the node (tests/v8/
/// wr1_counted_hold_test.zig), and the guards in `release` answer for the
/// free made whatever the counts say (dom.refcount's header).
pub const CountedRef = struct {
    /// The node held, or null for none.
    base: ?*NodeBase = null,
    /// The slab generation of the instance behind `base` when it was taken.
    generation: u64 = 0,

    /// Take one reference on `base`, the tree node of `instance` (nothing
    /// for null: not a node). The ref holds nothing before.
    pub fn take(self: *CountedRef, instance: *runtime.Instance, base: ?*NodeBase) void {
        std.debug.assert(self.base == null);
        const node = base orelse return;
        self.* = .{ .base = node, .generation = runtime.SlabAllocator.generationOf(instance) };
        refcount.holderRef(node);
    }

    /// Let it go - `instance` is the one it was taken for - unless the node
    /// went first (then it is forgotten). Safe on a ref holding nothing.
    pub fn release(self: *CountedRef, instance: *runtime.Instance) void {
        const node = self.base orelse return;
        self.base = null;
        if (runtime.SlabAllocator.generationOf(instance) != self.generation) return;
        if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
        refcount.holderDeref(node);
    }
};

// ============================================================================
// Task holds: what a queued native task keeps
// ============================================================================

/// One platform object a queued native task - a record with no wrapper and no
/// Instance owner - keeps until the task ends: refcount design 2.4's
/// `GCReachableRef`, in shadow mode. WebKit's `Node::queueTaskKeepingNodeAlive`
/// captures `GCReachableRef(node)` (Source/WebCore/dom/NodeInlines.h): a
/// counted reference plus a keep of the node's wrapper, which
/// `JSNodeOwner::isReachableFromOpaqueRoots` reads (GCReachableRefMap); Blink
/// posts such a task with `WrapPersistent(element)`
/// (HTMLElement::QueuePopoverToggleEvent).
///
/// A node is held twice over: a counted hold (`Hold`) and ONE counted
/// pending-activity keep of its wrapper (`engine.keepPlatformObjectAlive`).
/// A node with no wrapper is wrapped first, so the keep has a wrapper to
/// keep - in a detached realm too, where a kept wrapper hangs from the
/// realm's global object. (Since the redesign's P5 the agent's keeps also
/// walk a kept node's tree whether or not it is wrapped, rule 3.2 (c); the
/// net stays until the keeps need no wrapper in a detached realm either.)
/// A member that is not a node (a CloseWatcher) is kept, not counted.
///
/// Its ends are its owner's: `take` when the task is queued, `release`
/// exactly once when it ends - after its steps when it runs, or when it is
/// cancelled or dropped. It is not a raw pointer plus a generation: the hold
/// KEEPS its member; the generation only answers for a free the collector
/// does not make (the member's realm's end), as `Hold.get` does.
pub const TaskHold = struct {
    hold: Hold = .{},
    /// The member when it is not a node, with its generation.
    other: ?*runtime.Instance = null,
    other_generation: u64 = 0,
    /// Whether this hold took a pending-activity keep.
    kept: bool = false,
    state: enum(u8) { empty, held, released } = .empty,

    /// Hold `member` (a node, or any platform object) until `release`.
    pub fn take(self: *TaskHold, member: *runtime.Instance) void {
        std.debug.assert(self.state != .held);
        if (instance_bridge.getNodeBase(@ptrCast(member))) |base| {
            self.hold.link(member, base);
        } else {
            self.other = member;
            self.other_generation = runtime.SlabAllocator.generationOf(member);
        }
        self.state = .held;
        if (!member.ctx.hasEngine()) return;
        // The shadow-mode net: a node held by a keep must have a wrapper
        // for the keep to keep anything. Made in its relevant realm, then
        // kept, then the temporary hold let go.
        const made: ?engine.Owned = if (self.other == null and !engine.hasWrapper(member))
            engine.retainValue(member.ctx, .{ .instance = member }) catch null
        else
            null;
        defer if (made) |wrapper| wrapper.release();
        // A node whose wrapper could not be made (out of memory) takes no
        // keep: `keepPlatformObjectAlive` cannot say it failed, and on an
        // unwrapped member it records the keep in its realm's side table,
        // which out of memory records nothing - a release would then end a
        // keep nobody took, or another owner's (row 130 review F2;
        // docs/lessons/architecture-a-counted-keep-the-engine-may-not-record-must-not-be-released.md).
        // Its counted hold still keeps it. A member that is not a node keeps
        // the side-table keep a wrapper made later takes (a CloseWatcher is
        // held from its constructor, before the binding wraps it).
        if (self.other == null and !engine.hasWrapper(member)) return;
        engine.keepPlatformObjectAlive(member);
        self.kept = true;
    }

    /// The member, or null once it was freed outside the collector (its
    /// realm's end) - a teardown net, never the behaviour: the hold is what
    /// keeps it.
    pub fn get(self: *const TaskHold) ?*runtime.Instance {
        if (self.other) |member| {
            if (runtime.SlabAllocator.generationOf(member) != self.other_generation) return null;
            return member;
        }
        return self.hold.get();
    }

    /// Whether this hold holds a member now.
    pub fn isHeld(self: *const TaskHold) bool {
        return self.state == .held;
    }

    /// Let the member go: exactly once, at its owner's end. The keep ends
    /// first, while the member is live - one freed at its realm's end took
    /// its keep with its wrapper cache, so it is never released then - and
    /// the counted hold after it. A hold never taken ends nothing.
    pub fn release(self: *TaskHold) void {
        switch (self.state) {
            .empty => return,
            .released => {
                if (builtin.mode == .debug) std.debug.panic("node_holds.TaskHold {*} released twice", .{self});
                log.err("node_holds.TaskHold {*} released twice", .{self});
                return;
            },
            .held => {},
        }
        if (self.kept) if (self.get()) |member| engine.releasePlatformObject(member);
        self.kept = false;
        self.hold.unlink();
        self.other = null;
        self.state = .released;
    }
};

/// One node a holder will hand to script later, kept for it: refcount design
/// 2.4's `GCReachableRef` in shadow mode, for a holder whose node something
/// else keeps from the collector meanwhile - so, unlike `TaskHold`, it never
/// wraps. A MutationObserver's pending targets are the case (lane refcount5,
/// step 5c): the queued record that names a target holds it, and its
/// observer traces it (the redesign's P6), and wrapping every record's
/// target is the cost lane edges measured (2.55x on an observed parse;
/// docs/lessons/architecture-tracing-a-holders-nodes-makes-a-wrapper-per-node.md).
///
/// WebKit's GCReachableRef (Source/WebCore/dom/GCReachableRef.h) is a RefPtr
/// plus an entry in GCReachableRefMap, a HashCountedSet that
/// JSNodeOwner::isReachableFromOpaqueRoots reads to keep a disconnected
/// node's wrapper (bindings/js/JSNodeCustom.cpp). Here: a counted hold
/// (`Hold`) and ONE counted pending-activity keep of the node
/// (engine.keepPlatformObjectAlive): the agent's keeps walk the kept node's
/// tree whether or not it is wrapped (rule 3.2 (c)), and a wrapper made
/// later is kept with it - so its expandos last until the holder lets go, as
/// WebKit's GC-time read of the map does.
///
/// A node freed under it - its realm's coordinated teardown, the final sweep
/// - reads as gone (`Hold.stillHeld`): its keep went with the node, and its
/// `release` then makes no engine call. Released once; a release of a hold
/// that holds nothing does nothing.
pub const ReachableHold = struct {
    hold: Hold = .{},
    /// Whether this hold took a pending-activity keep.
    kept: bool = false,

    /// Hold `member` (a node: `base` is its tree node) and keep its wrapper.
    /// The hold holds nothing before.
    pub fn take(self: *ReachableHold, member: *runtime.Instance, base: *NodeBase) void {
        std.debug.assert(self.hold.node == null and !self.kept);
        self.hold.link(member, base);
        if (!member.ctx.hasEngine()) return;
        engine.keepPlatformObjectAlive(member);
        self.kept = true;
    }

    /// The node, or null once it was freed under the hold (a teardown net,
    /// never the behaviour: the hold is what keeps it).
    pub fn get(self: *const ReachableHold) ?*runtime.Instance {
        return self.hold.get();
    }

    /// Whether this holds `member` now: taken on it at the slab generation
    /// it was held at.
    pub fn holds(self: *const ReachableHold, member: *runtime.Instance) bool {
        return self.hold.node == member and Hold.stillHeld(member, self.hold.generation);
    }

    /// Let the node go: the keep first, while the node is alive, then the
    /// counted hold.
    pub fn release(self: *ReachableHold) void {
        if (self.kept) if (self.hold.get()) |member| engine.releasePlatformObject(member);
        self.kept = false;
        self.hold.unlink();
    }
};

/// A Browser's queued element tasks (`ElementTask`): a supplement of its
/// scope (runtime.BrowserScope, docs/instances.md rule 2), reached through
/// the realm of the element a task targets. It is what HTML's toggle task
/// trackers read (`ElementTask.pending`), and its counts are the books a test
/// and the Browser's end check: every hold taken is released.
///
/// Element tasks are queued and run on the Browser's window agent thread,
/// with its DOM; nothing here is touched from another thread.
pub const ElementTasks = struct {
    allocator: Allocator,
    first: ?*Entry = null,
    /// Task holds taken and released by the tasks of this Browser.
    holds_taken: u64 = 0,
    holds_released: u64 = 0,
    /// Tasks queued, and tasks that ended (run, cancelled or dropped).
    queued: u64 = 0,
    ended: u64 = 0,

    /// A queued task's link: its Payload's name, and whether it was
    /// cancelled.
    pub const Entry = struct {
        kind: []const u8,
        prev: ?*Entry = null,
        next: ?*Entry = null,
    };

    pub fn init(allocator: Allocator) ElementTasks {
        return .{ .allocator = allocator };
    }

    /// The scope's end, after the Browser's loop dropped every task it still
    /// had: nothing may be left.
    pub fn deinit(self: *ElementTasks) void {
        if (self.first != null or self.holds_taken != self.holds_released) {
            log.err("{d} element task holds taken, {d} released, at the Browser's end", .{ self.holds_taken, self.holds_released });
        }
    }

    /// The tasks of the Browser `realm` belongs to, made on first use; null
    /// for a realm with no Browser scope (a test realm).
    pub fn of(realm: runtime.Context) ?*ElementTasks {
        const scope = realm.browser_scope orelse return null;
        return scope.of(ElementTasks) catch null;
    }

    /// The tasks of the Browser `realm` belongs to, if any were queued.
    pub fn existingOf(realm: runtime.Context) ?*ElementTasks {
        const scope = realm.browser_scope orelse return null;
        return scope.existing(ElementTasks);
    }

    fn link(self: *ElementTasks, entry: *Entry) void {
        entry.prev = null;
        entry.next = self.first;
        if (self.first) |head| head.prev = entry;
        self.first = entry;
    }

    fn unlink(self: *ElementTasks, entry: *Entry) void {
        if (entry.prev) |prev| prev.next = entry.next else self.first = entry.next;
        if (entry.next) |next| next.prev = entry.prev;
        entry.prev = null;
        entry.next = null;
    }
};

/// HTML "queue an element task" for a task that keeps the platform objects it
/// will hand to script until it ends (WebKit `Node::queueTaskKeepingNodeAlive`),
/// with both ends built in, so every hold is released exactly once.
///
/// `Payload` declares:
///   * `held_count`: how many members the task holds; member 0 is the
///     element the task is queued given;
///   * `fn steps(payload: *Payload, held: []const TaskHold) void`: the task's
///     steps, run as a task of the element's realm; `held[i].get()` reads a
///     member (null only after a teardown - the task then skips it);
///   * optionally `fn deinit(payload: *Payload) void`: what the payload owns;
///   * optionally `queued_given_relevant_global = true`: the task is HTML's
///     "queue an element task" read to the letter - a global task given the
///     element's relevant global object, whose document is that global's
///     associated Document (`taskDocument`). Without it the task's document
///     is the element's node document.
///
/// The record goes when the task ends: when it runs (after its steps: the
/// running task is the holder while they run script), when it is cancelled
/// ("remove the task from its task queue": its holds end at once, and the
/// loop still frees the record), or when the loop drops it (a document that
/// can never be fully active again, the loop's end - which, for a Browser,
/// comes after its realms ended and before its scope does).
pub fn ElementTask(comptime Payload: type) type {
    return struct {
        const Self = @This();
        pub const held_count: usize = Payload.held_count;
        const kind: []const u8 = @typeName(Payload);

        entry: ElementTasks.Entry = .{ .kind = kind },
        /// The books of the Browser it was queued in; null for a realm with
        /// no Browser scope.
        tasks: ?*ElementTasks = null,
        /// Whether `entry` is in `tasks`' list: until the task runs, is
        /// cancelled or ends.
        linked: bool = false,
        holds: [held_count]TaskHold = @as([held_count]TaskHold, @splat(.{})),
        payload: Payload,
        allocator: Allocator,
        cancelled: bool = false,

        /// Queue the task given `members[0]`, the element, on its realm's event
        /// loop, with its node document as the task's document. Whether it
        /// was queued: false when the realm has no loop or memory ran out -
        /// then nothing was taken and `payload` was deinitialized. A queued
        /// task may already have ended when this returns (a closing loop
        /// drops it at once), so the caller keeps no pointer to it: a
        /// tracker reads `pending`.
        pub fn queue(members: [held_count]?*runtime.Instance, payload: Payload) bool {
            var owned = payload;
            const element = members[0] orelse {
                deinitPayload(&owned);
                return false;
            };
            const loop = element.ctx.getOptionalEventLoop() orelse {
                log.warn("{s} not queued: the element's realm has no event loop", .{kind});
                deinitPayload(&owned);
                return false;
            };
            const allocator = element.ctx.allocator;
            const self = allocator.create(Self) catch {
                log.warn("{s} not queued: out of memory", .{kind});
                deinitPayload(&owned);
                return false;
            };
            self.* = .{ .payload = owned, .allocator = allocator };
            const tasks = ElementTasks.of(element.ctx);
            for (members, &self.holds) |member, *slot| {
                const value = member orelse continue;
                slot.take(value);
                if (tasks) |books| books.holds_taken += 1;
            }
            if (tasks) |books| {
                books.link(&self.entry);
                books.queued += 1;
                self.tasks = books;
                self.linked = true;
            }
            const document = taskDocument(element);
            // The handoff: from here the loop owns the record, which may be
            // gone before queueTask returns.
            loop.queueTask(.{
                .callback = &run,
                .context = self,
                .drop = &drop,
                .document = document,
                .document_generation = if (document) |d| runtime.SlabAllocator.generationOf(d) else 0,
            });
            return true;
        }

        /// The document the loop runs the task for: HTML "queue an element
        /// task ... given element" queues a global task given element's
        /// relevant global object, whose document is the global's
        /// associated Document when it is a Window - here the Window
        /// itself, which the loop classifies through its navigable
        /// (dom.document_activity), as html/media's tasks do. So an element
        /// of a document no browsing context shows (DOMParser's) still has
        /// its task run in its realm's Window. A Payload that does not opt
        /// in keeps its node document.
        fn taskDocument(element: *runtime.Instance) ?*runtime.Instance {
            const relevant_global = comptime @hasDecl(Payload, "queued_given_relevant_global") and Payload.queued_given_relevant_global;
            if (!relevant_global) return interfaces.Node.get_ownerDocument(element) catch null;
            const realm = element.ctx.getRealm() orelse return null;
            const global: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return null));
            return if (std.mem.eql(u8, global.vtable.name, "Window")) global else null;
        }

        /// The task of this kind queued given `element` that has neither run
        /// nor been cancelled: HTML's toggle task tracker for it.
        pub fn pending(element: *runtime.Instance) ?*Self {
            const tasks = ElementTasks.existingOf(element.ctx) orelse return null;
            var current = tasks.first;
            while (current) |entry| : (current = entry.next) {
                if (!std.mem.eql(u8, entry.kind, kind)) continue;
                const self: *Self = @fieldParentPtr("entry", entry);
                if (self.holds[0].get() == element) return self;
            }
            return null;
        }

        /// HTML "remove the task from its task queue": the task will not
        /// run, so what it holds goes now. The loop still has the record;
        /// its run or drop frees it.
        pub fn cancel(self: *Self) void {
            if (self.cancelled) return;
            self.cancelled = true;
            self.leaveList();
            self.releaseHolds();
        }

        /// The member at `index`, or null after a teardown.
        pub fn held(self: *const Self, index: usize) ?*runtime.Instance {
            return self.holds[index].get();
        }

        fn run(data: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(data orelse return));
            defer self.end();
            if (self.cancelled) return;
            // The tracker forgets the task before its steps run, so a
            // listener that queues another one starts from its own state
            // (WebKit ToggleEventTask::queue exchanges its data out before
            // dispatching: Source/WebCore/dom/ToggleEventTask.cpp).
            self.leaveList();
            const element = self.holds[0].get() orelse return;
            // A realm retired by a navigation runs nothing.
            if (element.ctx.engine_ctx == null) return;
            engine.runTaskInRealm(element.ctx, steps, self) catch |err| {
                log.warn("{s} not run: {}", .{ kind, err });
            };
        }

        fn steps(data: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(data orelse return));
            Payload.steps(&self.payload, &self.holds);
        }

        fn drop(data: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(data orelse return));
            self.end();
        }

        fn leaveList(self: *Self) void {
            if (!self.linked) return;
            self.linked = false;
            self.tasks.?.unlink(&self.entry);
        }

        fn releaseHolds(self: *Self) void {
            for (&self.holds) |*slot| {
                if (!slot.isHeld()) continue;
                slot.release();
                if (self.tasks) |books| books.holds_released += 1;
            }
        }

        /// The task left the loop, run or not.
        fn end(self: *Self) void {
            self.leaveList();
            self.releaseHolds();
            if (self.tasks) |books| books.ended += 1;
            deinitPayload(&self.payload);
            self.allocator.destroy(self);
        }

        fn deinitPayload(payload: *Payload) void {
            if (comptime @hasDecl(Payload, "deinit")) payload.deinit();
        }
    };
}

/// A holder of many nodes, embedded in its owner's state: a MutationRecord's
/// target, siblings and added and removed nodes, a static NodeList's nodes,
/// an XPathResult's snapshot. One counted hold per node, in the holder's own
/// order; its owner's `traceHeldNodes` calls `trace`.
pub const Holder = struct {
    /// What the holds are allocated with.
    allocator: Allocator,
    /// The holds, in the holder's own order; owned.
    holds: []Hold = &.{},

    pub fn init(allocator: Allocator) Holder {
        return .{ .allocator = allocator };
    }

    /// Hold `nodes`, in order (`T` is `*runtime.Instance`,
    /// `?*runtime.Instance` - a null holds nothing - or `*NodeBase`, the tree
    /// nodes themselves, which spares a lookup each). The holder holds
    /// nothing yet.
    pub fn hold(self: *Holder, comptime T: type, nodes: []const T) Allocator.Error!void {
        std.debug.assert(self.holds.len == 0);
        if (nodes.len == 0) return;
        const holds = try self.allocator.alloc(Hold, nodes.len);
        for (nodes, holds) |item, *slot| {
            slot.* = .{};
            const held = resolve(T, item) orelse continue;
            slot.link(held.node, held.base);
        }
        self.holds = holds;
    }

    const Resolved = struct { node: *runtime.Instance, base: *NodeBase };

    /// A node to hold, as both its platform object and its tree node.
    fn resolve(comptime T: type, item: T) ?Resolved {
        switch (T) {
            *NodeBase => {
                const node: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(item) orelse return null));
                return .{ .node = node, .base = item };
            },
            *runtime.Instance => return .{ .node = item, .base = instance_bridge.getNodeBase(@ptrCast(item)) orelse return null },
            ?*runtime.Instance => {
                const node = item orelse return null;
                return .{ .node = node, .base = instance_bridge.getNodeBase(@ptrCast(node)) orelse return null };
            },
            else => @compileError("Holder.hold holds *NodeBase, *runtime.Instance or ?*runtime.Instance"),
        }
    }

    /// The node of hold `index` (see `Hold.get`).
    pub fn get(self: *const Holder, index: usize) ?*runtime.Instance {
        if (index >= self.holds.len) return null;
        return self.holds[index].get();
    }

    /// Let every node go: the holder is cleared or going. No engine call, so
    /// safe in any teardown.
    pub fn release(self: *Holder) void {
        for (self.holds) |*held| held.unlink();
        if (self.holds.len != 0) self.allocator.free(self.holds);
        self.holds = &.{};
    }

    /// The collector's pause: every held node's wrappers (`Hold.trace`). A
    /// connected node's tree is its document's, named once per holder; a
    /// node whose parent is the previous held node's parent, or the previous
    /// held node itself, is in a tree already named - querySelectorAll's
    /// tree order makes that the common case - so its trees are not looked
    /// up again; its own wrapper, if it has one, was named with that tree
    /// (a wrapped node is held, so the walk enters it).
    pub fn trace(self: *const Holder, tracer: *engine.Tracer) void {
        var last: ?*NodeBase = null;
        var last_document: ?*NodeBase = null;
        for (self.holds) |*held| {
            _ = held.get() orelse continue;
            const base = held.base;
            // Connected: its tree is its document's, named once.
            if (wrapper_tracing.connectedDocument(base)) |document| {
                if (document != last_document) wrapper_tracing.traceHeld(document, tracer);
                last_document = document;
                continue;
            }
            const parent = base.parent_node;
            if (last) |previous| {
                if (parent != null and (parent == previous.parent_node or parent == previous)) {
                    last = base;
                    continue;
                }
            }
            last = base;
            wrapper_tracing.traceHeld(base, tracer);
        }
    }
};

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
