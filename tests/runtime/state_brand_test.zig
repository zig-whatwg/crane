//! Phase 4 mechanism proof: offset-corrected, brand-checked state access.
//!
//! `Instance.getState(T)` is a bare `@ptrCast` of `instance.state` to `*T`. When an
//! ancestor's impl runs against a DERIVED instance - EventTarget's listener code on an
//! Element, say - that only reads the right bytes if the base state sits at offset 0 of
//! the derived state, at every level. Nothing guarantees it: `FlattenedState` is a plain
//! `struct { base, mixins, own }` with auto layout, and auto layout orders by descending
//! alignment, so a low-alignment base under high-alignment own fields moves `base` off
//! zero. tests/dom/state_layout_test.zig shows the hazard is real but currently latent.
//!
//! This file proves the REPLACEMENT works before it is wired into codegen:
//!   1. each interface carries a comptime table of {ancestor state type -> byte offset}
//!   2. lookup is by a unique comptime-assigned id per type, since `type` cannot cross
//!      the runtime boundary
//!   3. access adds the offset instead of assuming zero
//!   4. a type that is NOT in the chain is rejected - the brand check
//!
//! The first test is the Phase 4 exit criterion from the migration plan: a derived type
//! whose base has alignment < 8, read through the BASE getter. The naive pun fails it.

const std = @import("std");

// ---------------------------------------------------------------------------
// The mechanism
// ---------------------------------------------------------------------------

/// A runtime-comparable identity for a comptime type.
///
/// `type` cannot be passed or stored at runtime, so each state type gets a unique
/// address: one zero-sized static per instantiation of `Holder`. Comparing pointers
/// is exact, unlike comparing `@typeName` strings.
const TypeId = *const anyopaque;

fn Holder(comptime T: type) type {
    return struct {
        const marker: u8 = 0;
        comptime {
            _ = T;
        }
    };
}

fn typeId(comptime T: type) TypeId {
    return @ptrCast(&Holder(T).marker);
}

/// One entry of an interface's ancestry: an ancestor's state type and where that
/// ancestor's state begins inside THIS interface's state.
const Ancestor = struct {
    id: TypeId,
    offset: usize,
};

/// Walk `State` and every `base` beneath it, accumulating byte offsets.
///
/// Entry 0 is always the type itself at offset 0; each subsequent entry adds the
/// `@offsetOf(.., "base")` of the level above. This is what codegen would emit per
/// interface, and it is the whole reason the derived-to-base pun can be retired.
fn ancestorsOf(comptime State: type) []const Ancestor {
    comptime {
        var list: []const Ancestor = &.{};
        var Cur: type = State;
        var off: usize = 0;
        while (true) {
            list = list ++ [_]Ancestor{.{ .id = typeId(Cur), .offset = off }};
            if (!@hasField(Cur, "base")) break;
            const Base = @FieldType(Cur, "base");
            if (Base == void) break;
            off += @offsetOf(Cur, "base");
            Cur = Base;
        }
        return list;
    }
}

const BrandError = error{WrongInterface};

/// The replacement for `getState`: find T in the instance's ancestry and offset to it.
fn stateAs(comptime T: type, state: *anyopaque, ancestors: []const Ancestor) BrandError!*T {
    const want = typeId(T);
    for (ancestors) |a| {
        if (a.id == want) {
            const bytes: [*]u8 = @ptrCast(state);
            return @ptrCast(@alignCast(bytes + a.offset));
        }
    }
    return error.WrongInterface;
}

/// What `getState` does today, for contrast.
fn naivePun(comptime T: type, state: *anyopaque) *T {
    return @ptrCast(@alignCast(state));
}

// ---------------------------------------------------------------------------
// Types shaped exactly like runtime.FlattenedState
// ---------------------------------------------------------------------------

fn Flattened(comptime Base: ?type, comptime Own: type) type {
    return struct {
        base: if (Base) |B| B else void,
        mixins: struct {},
        own: Own,
    };
}

// align(1) base, align(8) derived own - the layout that moves `base` off zero.
const BaseState = Flattened(null, struct { flag: u8 = 0, kind: u8 = 0 });
const DerivedState = Flattened(BaseState, struct { big: u64 = 0, ptr: ?*anyopaque = null });
const UnrelatedState = Flattened(null, struct { nope: u32 = 0 });

test "PHASE 4 EXIT: a base attribute reads correctly through a derived instance" {
    // Precondition: this is only a meaningful test while the layout actually differs.
    // If Zig's layout rules change so base lands at 0, the naive pun would pass by luck
    // and this test would prove nothing - so assert the hazard is present.
    try std.testing.expect(@offsetOf(DerivedState, "base") != 0);

    var derived: DerivedState = .{
        .base = .{ .base = {}, .mixins = .{}, .own = .{ .flag = 0xAB, .kind = 0xCD } },
        .mixins = .{},
        .own = .{ .big = 0xDEAD_BEEF_DEAD_BEEF, .ptr = null },
    };
    const erased: *anyopaque = @ptrCast(&derived);
    const ancestors = comptime ancestorsOf(DerivedState);

    // The base's impl asks for ITS OWN state type, running on a derived instance.
    const as_base = try stateAs(BaseState, erased, ancestors);
    try std.testing.expectEqual(@as(u8, 0xAB), as_base.own.flag);
    try std.testing.expectEqual(@as(u8, 0xCD), as_base.own.kind);

    // And the derived type still reads its own state.
    const as_derived = try stateAs(DerivedState, erased, ancestors);
    try std.testing.expectEqual(@as(u64, 0xDEAD_BEEF_DEAD_BEEF), as_derived.own.big);
}

test "the naive pun gets this wrong - it reads the derived's bytes as the base's" {
    // Documents precisely what today's getState does on the same data, so the fix
    // cannot be dismissed as theoretical.
    var derived: DerivedState = .{
        .base = .{ .base = {}, .mixins = .{}, .own = .{ .flag = 0xAB, .kind = 0xCD } },
        .mixins = .{},
        .own = .{ .big = 0xDEAD_BEEF_DEAD_BEEF, .ptr = null },
    };
    const erased: *anyopaque = @ptrCast(&derived);

    const punned = naivePun(BaseState, erased);
    // It reads offset 0, which under this layout is the derived's `own.big`, not the
    // base at all. The value is whatever happens to sit there - NOT 0xAB.
    try std.testing.expect(punned.own.flag != 0xAB);
}

test "brand check rejects a type that is not in the chain" {
    var derived: DerivedState = .{
        .base = .{ .base = {}, .mixins = .{}, .own = .{} },
        .mixins = .{},
        .own = .{},
    };
    const erased: *anyopaque = @ptrCast(&derived);
    const ancestors = comptime ancestorsOf(DerivedState);

    // Today this would silently succeed and hand back garbage typed as UnrelatedState.
    try std.testing.expectError(error.WrongInterface, stateAs(UnrelatedState, erased, ancestors));
}

test "ancestry table has one entry per level, innermost first" {
    const a = comptime ancestorsOf(DerivedState);
    try std.testing.expectEqual(@as(usize, 2), a.len);
    try std.testing.expectEqual(@as(usize, 0), a[0].offset);
    try std.testing.expectEqual(typeId(DerivedState), a[0].id);
    try std.testing.expectEqual(@offsetOf(DerivedState, "base"), a[1].offset);
    try std.testing.expectEqual(typeId(BaseState), a[1].id);

    // A root type has exactly itself.
    const r = comptime ancestorsOf(BaseState);
    try std.testing.expectEqual(@as(usize, 1), r.len);
    try std.testing.expectEqual(@as(usize, 0), r[0].offset);
}

test "typeId is stable per type and distinct across types" {
    try std.testing.expectEqual(typeId(BaseState), typeId(BaseState));
    try std.testing.expect(typeId(BaseState) != typeId(DerivedState));
    try std.testing.expect(typeId(BaseState) != typeId(UnrelatedState));
}
