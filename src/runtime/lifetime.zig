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

/// What a counted type's VTable points at. One table for every counted type:
/// the runtime dispatches through it, and the owner the hooks name decides.
pub const Counted = struct {
    /// What the type counts as, for diagnostics.
    kind: Kind,

    pub const Kind = enum { node };
};

/// The table every node type's VTable shares.
pub const node: Counted = .{ .kind = .node };

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
