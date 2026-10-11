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
//! SHADOW MODE (steps 3 to 6): the references are taken and released and the
//! counts kept and checked, but they decide nothing; frees are still the
//! collector's. Step 7 lets them decide.

const std = @import("std");
const builtin = @import("builtin");
const Instance = @import("instance.zig").Instance;

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
};

// process-wide: dom.refcount's two functions, installed once while the process starts (refcount.install, from Document's and Node's installHooks) and the same for every Browser and thread; read-only after
var hooks: Hooks = .{};

/// The owner of the counts installs its hooks: once, while the process starts
/// (its caller asserts it). A field left null keeps what is installed.
pub fn install(owned: Hooks) void {
    if (owned.acquire) |f| hooks.acquire = f;
    if (owned.release) |f| hooks.release = f;
    if (owned.forget) |f| hooks.forget = f;
}

/// Tests: replace the hooks, returning the ones there were.
pub fn swapHooksForTest(replacement: Hooks) Hooks {
    if (!builtin.is_test) @compileError("swapHooksForTest is for tests");
    const previous = hooks;
    hooks = replacement;
    return previous;
}

/// `instance`'s wrapper was made and cached: it takes its reference. The
/// counted object it now holds, for the adapter to keep beside the wrapper and
/// hand to `wrapperReleased` exactly once; null for a type that does not count
/// (`VTable.counted`), or when no owner is installed.
pub fn wrapperAcquired(instance: *Instance) ?*anyopaque {
    _ = instance.vtable.counted orelse return null;
    const acquire = hooks.acquire orelse return null;
    return acquire(instance);
}

/// The wrapper that `wrapperAcquired` answered `target` for lets its
/// reference go: finalized after a collection (V8's second pass), removed,
/// replaced, or at its realm's end - or the target's own teardown began while
/// the wrapper lived (shadow mode: the collector still frees). Never inside a
/// collection; on the agent's thread.
pub fn wrapperReleased(target: *anyopaque) void {
    const release = hooks.release orelse return;
    release(target);
}

/// A wrapper's reference is dropped without `wrapperReleased`, because its
/// target is gone: the collector freed the node while the wrapper waited for
/// its finalizer (a collected root's teardown frees its subtree, whose
/// wrappers died in the same collection), or the realm's objects go with a
/// batch free. SHADOW MODE only: once counts decide (step 7) a node with a
/// wrapper is held, and is never freed under it.
pub fn wrapperForgotten() void {
    const forget = hooks.forget orelse return;
    forget();
}

/// The comptime predicate `buildVTable` fills `VTable.counted` with: `&node`
/// when some level of `State`'s `base` chain keeps an `_internal` pointer
/// whose target has a `node_base` field (Node's InternalState - the one node
/// state; nodes are what count, decision D3), else null - the DEFAULT, pinned
/// by tests/runtime/vtable_counted_test.zig.
pub fn countedOf(comptime State: type) ?*const Counted {
    comptime {
        var Level: type = State;
        while (true) {
            if (@typeInfo(Level) != .@"struct") return null;
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

/// Whether `Internal` - an `_internal` field's type - points at a struct with
/// a `node_base` field.
fn keepsNodeBase(comptime Internal: type) bool {
    comptime {
        var T: type = Internal;
        if (@typeInfo(T) == .optional) T = @typeInfo(T).optional.child;
        if (@typeInfo(T) != .pointer) return false;
        T = @typeInfo(T).pointer.child;
        return @typeInfo(T) == .@"struct" and @hasField(T, "node_base");
    }
}
