//! runtime.OwnState: an impl's internal state kept in its instance's generated
//! State (`own._internal`) instead of a hash table keyed by the instance's
//! address (lane perf2, batch 2: tmp/plans/perf2b2-design.md; since batch 6
//! a bit of the chain's live word says it is made). And
//! Instance.stateAs, which finds an ancestor's state in O(1): the answer of
//! the scan it replaces, for every ancestor and every non-member.
//!
//! The states here are built the way codegen builds them (runtime.FlattenedState,
//! an `_internal` pointer in each level's own fields, the ancestry from
//! runtime.ancestorsOf), so the same lookups serve the generated interfaces.
//! Since lane perf2 batch 5 (Z7) each level's state is kept by value in its own
//! State (`_embedded`), so `create` allocates nothing.

const std = @import("std");
const runtime = @import("runtime");

const testing = std.testing;
const BrowserScope = runtime.BrowserScope;

/// A state that owns memory, as an element's attribute list does.
const Owning = struct {
    bytes: ?[]u8 = null,

    /// Kept by value in its State (runtime.FlattenedState's `_embedded`).
    pub const embedded_in_state = true;

    pub fn deinit(self: *Owning) void {
        if (self.bytes) |bytes| testing.allocator.free(bytes);
        self.bytes = null;
    }
};

/// Another level's state: what its impl keeps.
const RootInternal = struct {
    listeners: u32 = 0,
    pub const embedded_in_state = true;
};

// A chain of three levels, as EventTarget <- Node <- Element; each level's
// own fields end with `_internal`, as codegen writes them. The odd field
// sizes put each `base` away from offset 0 (auto layout).
const RootState = runtime.FlattenedState(null, &.{}, struct {
    flag: u8 = 0,
    _internal: ?*RootInternal = null,
});
const MidState = runtime.FlattenedState(RootState, &.{}, struct {
    wide: u64 = 0,
    small: u8 = 0,
    _internal: ?*Owning = null,
});
const LeafState = runtime.FlattenedState(MidState, &.{}, struct {
    a: u16 = 0,
    b: u128 = 0,
    _internal: ?*Owning = null,
});
/// Not on the chain: the brand check rejects it.
const OtherState = runtime.FlattenedState(null, &.{}, struct {
    _internal: ?*Owning = null,
});

const no_methods = .{};
const leaf_vtable: runtime.VTable = .{ .name = "Leaf", .ancestors = runtime.ancestorsOf(LeafState), .deinit = null, .methods_ptr = &no_methods };
const mid_vtable: runtime.VTable = .{ .name = "Mid", .ancestors = runtime.ancestorsOf(MidState), .deinit = null, .methods_ptr = &no_methods };
const other_vtable: runtime.VTable = .{ .name = "Other", .ancestors = runtime.ancestorsOf(OtherState), .deinit = null, .methods_ptr = &no_methods };
/// A hand-written vtable with no ancestry (a test mock, the static-call vehicle).
const bare_vtable: runtime.VTable = .{ .name = "Bare", .deinit = null, .methods_ptr = &no_methods };

const MidOwn = runtime.OwnState(MidState, Owning);
const LeafOwn = runtime.OwnState(LeafState, Owning);
const RootOwn = runtime.OwnState(RootState, RootInternal);

/// An instance of `State` in `scope`, its state block from the scope's arena,
/// zeroed as Instance.init zeroes it.
fn make(scope: *BrowserScope, comptime State: type, vtable: *const runtime.VTable) !*runtime.Instance {
    const instance = try scope.slab.alloc(vtable);
    const state = try scope.arena.create(State);
    @memset(std.mem.asBytes(state), 0);
    instance.state = state;
    return instance;
}

/// The old scan, kept here as the oracle.
fn scan(instance: *const runtime.Instance, comptime T: type) ?*T {
    for (instance.vtable.ancestors) |a| {
        if (a.id == runtime.typeId(T)) {
            const bytes: [*]u8 = @ptrCast(instance.state);
            return @ptrCast(@alignCast(bytes + a.offset));
        }
    }
    return null;
}

test "stateAs finds every ancestor of a deep chain where the scan did, and nothing that is not on it" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const leaf = try make(&scope, LeafState, &leaf_vtable);
    const mid = try make(&scope, MidState, &mid_vtable);
    const other = try make(&scope, OtherState, &other_vtable);

    const leaf_state: *LeafState = @ptrCast(@alignCast(leaf.state));
    try testing.expectEqual(leaf_state, leaf.stateAs(LeafState).?);
    try testing.expectEqual(&leaf_state.base, leaf.stateAs(MidState).?);
    try testing.expectEqual(&leaf_state.base.base, leaf.stateAs(RootState).?);
    inline for (.{ LeafState, MidState, RootState, OtherState }) |T| {
        try testing.expectEqual(scan(leaf, T), leaf.stateAs(T));
        try testing.expectEqual(scan(mid, T), mid.stateAs(T));
        try testing.expectEqual(scan(other, T), other.stateAs(T));
    }
    // A shorter chain has no deeper level, a foreign one no level at all.
    try testing.expect(mid.stateAs(LeafState) == null);
    try testing.expect(other.stateAs(MidState) == null);
    try testing.expect(leaf.stateAs(OtherState) == null);
    // At least one base is off offset 0, or the offsets prove nothing.
    try testing.expect(@intFromPtr(&leaf_state.base) != @intFromPtr(leaf_state) or
        @intFromPtr(&leaf_state.base.base) != @intFromPtr(&leaf_state.base));
}

test "stateAs on a vtable with no ancestry answers null" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const bare = try make(&scope, LeafState, &bare_vtable);
    try testing.expect(bare.stateAs(LeafState) == null);
    try testing.expect(bare.stateAs(RootState) == null);
}

test "OwnState: a level's state is its instance's own, beside the other levels' and at the right offset" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const leaf = try make(&scope, LeafState, &leaf_vtable);
    const mid = try make(&scope, MidState, &mid_vtable);

    try testing.expect(MidOwn.get(leaf) == null);
    const leaf_mid = try MidOwn.create(leaf);
    leaf_mid.bytes = try testing.allocator.dupe(u8, "leaf's mid");
    const leaf_own = try LeafOwn.create(leaf);
    const leaf_root = try RootOwn.create(leaf);
    leaf_root.listeners = 3;
    const mid_mid = try MidOwn.create(mid);

    // The reference is the generated field of that level, and the state is
    // that level's own `_embedded`: inside the instance's one State block.
    const leaf_state: *LeafState = @ptrCast(@alignCast(leaf.state));
    try testing.expectEqual(&leaf_state.base._embedded, leaf_mid);
    try testing.expectEqual(&leaf_state._embedded, leaf_own);
    try testing.expectEqual(&leaf_state.base.base._embedded, leaf_root);
    // Made: each level's bit of the root's live word (lane perf2 batch 6: a
    // pointer per level before, `own._internal`).
    try testing.expectEqual(@as(u32, 0b111), leaf_state.base.base._live);
    try testing.expectEqual(leaf_mid, MidOwn.get(leaf).?);
    try testing.expectEqual(mid_mid, MidOwn.get(mid).?);
    try testing.expectEqual(@as(u32, 3), RootOwn.get(leaf).?.listeners);
    try testing.expect(LeafOwn.get(mid) == null);
    try testing.expect(MidOwn.contains(leaf) and !LeafOwn.contains(mid));

    // Removed: null, and the other levels keep theirs.
    MidOwn.get(leaf).?.deinit();
    MidOwn.remove(leaf);
    try testing.expect(MidOwn.get(leaf) == null);
    try testing.expectEqual(@as(u32, 0b101), leaf_state.base.base._live);
    try testing.expectEqual(leaf_own, LeafOwn.get(leaf).?);
    // Removing again does nothing.
    MidOwn.remove(leaf);
    LeafOwn.remove(leaf);
    RootOwn.remove(leaf);
    MidOwn.remove(mid);
}

test "OwnState: a freed slot answers null, and its reissue starts with no state" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const leaf = try make(&scope, LeafState, &leaf_vtable);
    _ = try MidOwn.create(leaf);
    MidOwn.remove(leaf);
    scope.slab.free(leaf);
    // The free list's pointer now sits where the vtable was: get must not read it.
    try testing.expect(MidOwn.get(leaf) == null);
    try testing.expect(!MidOwn.contains(leaf));

    // The slab hands the address out again (LIFO) to an object with a fresh,
    // zeroed state block: nothing of the dead one is found there.
    const again = try make(&scope, LeafState, &leaf_vtable);
    try testing.expectEqual(leaf, again);
    try testing.expect(MidOwn.get(again) == null);
}

test "OwnState's sweep frees what no deinit reached, in its own Browser only, and skips every other object" {
    var a = BrowserScope.init(testing.allocator);
    defer a.deinit();
    var b = BrowserScope.init(testing.allocator);
    defer b.deinit();

    // In A: two orphans whose deinit never ran, one torn down properly, a
    // shorter chain, a foreign type and a mock with no ancestry.
    var orphans: [2]*runtime.Instance = undefined;
    for (&orphans, 0..) |*slot, i| {
        slot.* = try make(&a, LeafState, &leaf_vtable);
        const state = try MidOwn.create(slot.*);
        state.bytes = try std.fmt.allocPrint(testing.allocator, "orphan {d}", .{i});
    }
    const done = try make(&a, LeafState, &leaf_vtable);
    _ = try MidOwn.create(done);
    MidOwn.remove(done);
    const mid = try make(&a, MidState, &mid_vtable);
    (try MidOwn.create(mid)).bytes = try testing.allocator.dupe(u8, "mid orphan");
    const other = try make(&a, OtherState, &other_vtable);
    _ = other;
    const bare = try make(&a, LeafState, &bare_vtable);
    _ = bare;
    // A freed slot of A, which the walk must not read.
    const freed = try make(&a, LeafState, &leaf_vtable);
    a.slab.free(freed);
    // In B: one of the same type, which A's sweep must leave.
    const in_b = try make(&b, LeafState, &leaf_vtable);
    (try MidOwn.create(in_b)).bytes = try testing.allocator.dupe(u8, "b");

    try testing.expectEqual(@as(usize, 3), MidOwn.count(&a));
    try testing.expectEqual(@as(usize, 1), MidOwn.count(&b));

    MidOwn.deinitAllAndClear(&a);
    try testing.expectEqual(@as(usize, 0), MidOwn.count(&a));
    for (orphans) |orphan| try testing.expect(MidOwn.get(orphan) == null);
    try testing.expect(MidOwn.get(mid) == null);
    try testing.expectEqualStrings("b", MidOwn.get(in_b).?.bytes.?);

    MidOwn.get(in_b).?.deinit();
    MidOwn.remove(in_b);
    try testing.expectEqual(@as(usize, 0), MidOwn.count(&b));
}
