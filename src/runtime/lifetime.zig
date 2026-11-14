//! runtime.lifetime: the wrapper's counted reference (refcount design 2.1,
//! step 4 of tmp/plans/refcount-design.md).
//!
//! A wrapper owns one reference to a counted instance - WebKit's JSDOMWrapper
//! holds a `Ref<T>`, and pre-Oilpan Blink's second weak callback dropped the
//! object's reference. The engine adapter takes it when it caches a wrapper
//! (`wrapperAcquired`) and releases it, on the agent's thread and never inside
//! a collection, when the wrapper is finalized (`wrapperReleased`). The adapter
//! decides nothing about what the reference means: the owner of the counts
//! does (dom.refcount for nodes, decision D3 - nodes first).
//!
//! Which types count is `VTable.counted`, filled at comptime by
//! `buildVTable` (`countedOf`); a type with none keeps today's path - its
//! wrapper owns it outright and the collector frees it through
//! `gc.onObjectFreed`.
//!
//! Since step 7 the counts decide every free of a node during its realm's
//! life: the wrapper's release only lets its reference go, and the owner of
//! the counts queues a tree left with no hold (dom.refcount's header names the
//! two frees still made whatever the counts say).

const std = @import("std");
const builtin = @import("builtin");
const Instance = @import("instance.zig").Instance;
const Hook = @import("process").Hook;
const engine = @import("engine");

/// What a counted type's VTable points at. One table for every counted type:
/// the runtime dispatches through it, and the owner the hooks name decides.
pub const Counted = struct {
    /// What the type counts as, for diagnostics.
    kind: Kind,

    pub const Kind = enum { node };
};

/// The table every node type's VTable shares.
pub const node: Counted = .{ .kind = .node };

/// What the owner of the counts installs (dom.refcount, from its `install`,
/// at process start).
pub const Hooks = struct {
    /// A wrapper of `instance` was made: take one reference on the counted
    /// object behind it and return that object (a node's NodeBase), which the
    /// adapter keeps beside the wrapper and hands back to `release`; null when
    /// there is nothing behind it to count.
    acquire: ?*const fn (instance: *Instance) ?*anyopaque = null,
    /// The wrapper that took a reference on `target` is finalized (or the
    /// target's own teardown began under it): drop that reference.
    release: ?*const fn (target: *anyopaque) void = null,
    /// A wrapper's reference whose target was freed under it, not through a
    /// teardown the adapter heard (`wrapperForgotten`): diagnostics and tests
    /// only - the count went with the node.
    forget: ?*const fn () void = null,
    /// The engine's wrapper slot of `target` - what `acquire` answers for a
    /// counted object (a node's NodeBase): `slotOf`.
    slot_of: ?*const fn (target: *anyopaque) *engine.NodeWrapperSlot = null,
    /// The counted object whose slot `slot` is - `slot_of`'s inverse
    /// (`targetOfSlot`).
    target_of_slot: ?*const fn (slot: *engine.NodeWrapperSlot) *anyopaque = null,
    /// The walk (the wrapper redesign's P5, tmp/redesign/wrapper-redesign-
    /// design.md 3.3 and 4.4): `target` - a counted object, as `acquire`
    /// answers it - has a wrapper the engine's collector reached, or is
    /// kept; name every wrapper it keeps to the engine (engine.
    /// traceNodeWrapper), deduplicated per collection (engine.
    /// traceVisitOnce). `target`'s own wrapper is the engine's to keep (it
    /// reached it, or roots a kept one). Runs INSIDE the collection's atomic
    /// pause: read-only, no allocation, no other engine operation
    /// (dom.wrapper_tracing).
    trace_tree: ?*const fn (target: *anyopaque, tracer: *engine.Tracer) void = null,
};

// process-wide: dom.refcount's two functions, installed once while the process starts (refcount.install, from Document's and Node's installHooks) and the same for every Browser and thread; read-only after
var hooks: Hook(Hooks) = .init(.{});

/// The owner of the counts installs its hooks: once, while the process starts
/// (the slot refuses any other write). A field left null keeps what is
/// installed. Installing what is installed writes nothing (`merged`, and
/// Hook.install compares): a test start's re-install while another Browser's
/// thread reads the hooks is then no data race (ThreadSanitizer, the
/// many-Browsers variant: lane tsanfix1's sc2_shadow_import_drop).
pub fn install(owned: Hooks) void {
    const current = hooks.get();
    hooks.install(merged(current, owned) orelse current);
}

/// `current` with `owned`'s non-null fields, or null when that changes
/// nothing - the install then writes nothing.
fn merged(current: Hooks, owned: Hooks) ?Hooks {
    var next = current;
    if (owned.acquire) |f| next.acquire = f;
    if (owned.release) |f| next.release = f;
    if (owned.forget) |f| next.forget = f;
    if (owned.slot_of) |f| next.slot_of = f;
    if (owned.target_of_slot) |f| next.target_of_slot = f;
    if (owned.trace_tree) |f| next.trace_tree = f;
    return if (std.meta.eql(next, current)) null else next;
}

test "installing the hooks already installed writes nothing; a new or changed one is a write" {
    const T = struct {
        fn acquire(_: *Instance) ?*anyopaque {
            return null;
        }
        fn release(_: *anyopaque) void {}
        fn otherRelease(_: *anyopaque) void {}
    };
    const installed: Hooks = .{ .acquire = &T.acquire, .release = &T.release };
    // A test start's re-install - the same functions, or a part of them.
    try std.testing.expect(merged(installed, installed) == null);
    try std.testing.expect(merged(installed, .{ .release = &T.release }) == null);
    try std.testing.expect(merged(installed, .{}) == null);
    // The process start's first install, and a different function.
    try std.testing.expect(merged(.{}, installed) != null);
    const changed = merged(installed, .{ .release = &T.otherRelease }) orelse return error.TestExpectedWrite;
    try std.testing.expect(changed.release == &T.otherRelease);
    try std.testing.expect(changed.acquire == &T.acquire);
}

/// The hooks as installed (or as a live override has them): a test's
/// starting point for `overrideHooksForTest` - the process start's hooks
/// with one field changed.
pub fn installedHooks() Hooks {
    return hooks.get();
}

/// A test's override of the hooks (`overrideHooksForTest`).
pub const HooksOverride = Hook(Hooks).Override;

/// Tests: `replacement` until the returned guard's `restore()`, which the
/// test calls before it ends (Hook.overrideForTest). Start the process
/// first: its start installs dom.refcount's hooks UNDER the override, and
/// the restore brings those back.
pub fn overrideHooksForTest(replacement: Hooks) HooksOverride {
    return hooks.overrideForTest(replacement);
}

/// `instance`'s wrapper was made and cached: it takes its reference. The
/// counted object it now holds, for the adapter to keep beside the wrapper and
/// hand to `wrapperReleased` exactly once; null for a type that does not count
/// (`VTable.counted`), or when no owner is installed.
pub fn wrapperAcquired(instance: *Instance) ?*anyopaque {
    _ = instance.vtable.counted orelse return null;
    const acquire = hooks.read().acquire orelse return null;
    return acquire(instance);
}

/// The wrapper that `wrapperAcquired` answered `target` for lets its
/// reference go: finalized after a collection (V8's second pass), removed,
/// replaced, or at its realm's end - or the target's own teardown began while
/// the wrapper lived (a forced realm end's coordinated teardown). Never inside
/// a collection; on the agent's thread.
pub fn wrapperReleased(target: *anyopaque) void {
    const release = hooks.read().release orelse return;
    release(target);
}

/// The engine's inline wrapper slot of `target` - a counted object, as
/// `wrapperAcquired` answers it (a node's NodeBase) - for the adapter to read
/// and write (the wrapper redesign's P1, tmp/redesign/wrapper-redesign-
/// design.md section 3.3): the adapter never names a node's field. Installed
/// by the owner of the counts with its other hooks, at process start; a
/// target exists only once that owner is installed.
pub fn slotOf(target: *anyopaque) *engine.NodeWrapperSlot {
    const slot_of = hooks.read().slot_of orelse @panic("runtime.lifetime.slotOf: no owner of the counts installed its slot_of hook");
    return slot_of(target);
}

/// The counted object (a node's NodeBase) whose engine wrapper slot `slot`
/// is: `slotOf`'s inverse, for an adapter that keeps the slot's address and
/// not the node's - V8's node anchor (the wrapper redesign's P4,
/// tmp/redesign/wrapper-redesign-design.md 4.1), whose marking reads its
/// slot with no call into the host - and still never names a node's field.
/// Installed with `slot_of`, at process start.
pub fn targetOfSlot(slot: *engine.NodeWrapperSlot) *anyopaque {
    const target_of_slot = hooks.read().target_of_slot orelse @panic("runtime.lifetime.targetOfSlot: no owner of the counts installed its target_of_slot hook");
    return target_of_slot(slot);
}

/// The walk (`Hooks.trace_tree`) from `target`, a counted object with a
/// reachable wrapper or a keep, inside the engine's collector: every wrapper
/// it keeps is named to `tracer`. False, and nothing walked, when no owner
/// of the counts installed the walk (or a test's override removed it): the
/// engine then keeps only what its own edges keep.
pub fn traceTree(target: *anyopaque, tracer: *engine.Tracer) bool {
    const trace_tree = hooks.read().trace_tree orelse return false;
    trace_tree(target, tracer);
    return true;
}

/// Whether the walk is installed (`Hooks.trace_tree`): always, outside a
/// test's override that removes it (tests/v8/wrapper_walk_test.zig's
/// negative control). The holders' traces (VTable.trace_held_nodes) walk
/// through it too, so the adapter skips them when it is absent.
pub fn walkInstalled() bool {
    return hooks.read().trace_tree != null;
}

/// A wrapper's reference is dropped without `wrapperReleased`, because its
/// target is gone: the collector freed the node while the wrapper waited for
/// its finalizer, or the realm's objects go with a batch free. Since step 7 a
/// node with a wrapper is held, so only a free made whatever the counts say
/// gets here: a forced realm end's coordinated teardown.
pub fn wrapperForgotten() void {
    const forget = hooks.read().forget orelse return;
    forget();
}

/// The comptime predicate `buildVTable` fills `VTable.counted` with: `&node`
/// when some level of `State`'s `base` chain keeps a state that declares
/// `counted_node` (Node's InternalState - the one node state; nodes are what
/// count, decision D3) - by value (`_embedded`, as Node's is since lane perf2 batch
/// 5, with no `_internal` pointer since batch 6) or behind its `_internal`
/// pointer - else null - the DEFAULT, pinned by
/// tests/runtime/vtable_counted_test.zig and perf2b6_live_flags_test.zig.
pub fn countedOf(comptime State: type) ?*const Counted {
    comptime {
        var Level: type = State;
        while (true) {
            if (@typeInfo(Level) != .@"struct") return null;
            if (@hasField(Level, "_embedded") and keepsNodeBase(*@FieldType(Level, "_embedded"))) return &node;
            if (@hasField(Level, "own")) {
                const Own = @FieldType(Level, "own");
                if (@typeInfo(Own) == .@"struct" and @hasField(Own, "_internal") and keepsNodeBase(@FieldType(Own, "_internal"))) return &node;
            }
            if (!@hasField(Level, "base")) return null;
            const Base = @FieldType(Level, "base");
            if (Base == void) return null;
            Level = Base;
        }
    }
}

/// The VTable's `trace_held_nodes` for an interface whose generated `State`
/// is `State` (the wrapper redesign's P6, design 3.3 "new VTable entry"):
/// every level of its chain whose impl's InternalState declares
/// `pub fn traceHeldNodes(instance: *Instance, tracer: *engine.Tracer)
/// void` is called, the most derived first; null when none does. Found
/// through the generated State's own fields, as `countedOf` finds a node -
/// `own._internal`'s pointee, or `_embedded` - so nothing names an impl. The
/// function gets the INSTANCE and finds its own state however its impl
/// keeps it; it runs in the collector's atomic pause (VTable.
/// trace_held_nodes).
pub fn heldNodesOf(comptime State: type) ?*const fn (*Instance, *engine.Tracer) void {
    comptime {
        var found: []const type = &.{};
        var Level: type = State;
        while (true) {
            if (@typeInfo(Level) != .@"struct") break;
            if (@hasField(Level, "_embedded")) {
                if (tracerOf(@FieldType(Level, "_embedded"))) |T| found = found ++ &[_]type{T};
            }
            if (@hasField(Level, "own")) {
                const Own = @FieldType(Level, "own");
                if (@typeInfo(Own) == .@"struct" and @hasField(Own, "_internal")) {
                    if (tracerOf(@FieldType(Own, "_internal"))) |T| {
                        if (std.mem.indexOfScalar(type, found, T) == null) found = found ++ &[_]type{T};
                    }
                }
            }
            if (!@hasField(Level, "base")) break;
            const Base = @FieldType(Level, "base");
            if (Base == void) break;
            Level = Base;
        }
        if (found.len == 0) return null;
        const levels = found;
        const Thunk = struct {
            fn trace(instance: *Instance, tracer: *engine.Tracer) void {
                inline for (levels) |T| T.traceHeldNodes(instance, tracer);
            }
        };
        return &Thunk.trace;
    }
}

/// The InternalState type behind `Field` - an `_internal` pointer (optional
/// or not) or an `_embedded` value - when it declares `traceHeldNodes`.
fn tracerOf(comptime Field: type) ?type {
    comptime {
        var T: type = Field;
        if (@typeInfo(T) == .optional) T = @typeInfo(T).optional.child;
        if (@typeInfo(T) == .pointer) T = @typeInfo(T).pointer.child;
        if (@typeInfo(T) != .@"struct") return null;
        return if (@hasDecl(T, "traceHeldNodes")) T else null;
    }
}

/// Whether `Internal` - an `_internal` field's type, or a pointer to an
/// `_embedded` one - points at a node's state: a struct that DECLARES it,
/// `pub const counted_node = true;` (Node's InternalState, which keeps the
/// node's NodeBase by value). A declaration, as `embedded_in_state` is - not
/// a field's name: the predicate keyed on a field called `node_base` until
/// lane nm1 removed that field (Node's pointer to its own NodeBase, 8 bytes
/// a node), and a field kept for its name is read by no one who can see why
/// (lesson codegen-a-generated-field-can-be-read-for-its-presence). The
/// DEFAULT is "not counted": no declaration, or a false one.
fn keepsNodeBase(comptime Internal: type) bool {
    comptime {
        var T: type = Internal;
        if (@typeInfo(T) == .optional) T = @typeInfo(T).optional.child;
        if (@typeInfo(T) != .pointer) return false;
        T = @typeInfo(T).pointer.child;
        if (@typeInfo(T) != .@"struct" or !@hasDecl(T, "counted_node")) return false;
        return T.counted_node;
    }
}
