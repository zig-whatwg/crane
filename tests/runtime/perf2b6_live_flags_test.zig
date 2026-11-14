//! A level's internal state kept by value in its State (runtime.OwnState, the
//! State's `_embedded`) needs no pointer to it: the pointer said only "made and
//! not yet torn down", 8 bytes a level, five on a div (lane perf2 batch 6;
//! tmp/plans/perf2b5-design.md 3.2, "a flag word instead"). A level whose
//! impl keeps no state at all (`InternalState = struct {}`, 1,001 impls) needs
//! none either. So:
//!
//! - an embedded level and an empty level keep no `own._internal`; a level
//!   whose state is its own block (InstanceRegistry, or set by hand) keeps it;
//! - the chain's root keeps ONE live word, a bit per level (its depth from the
//!   root), which OwnState sets in `create` and clears in `remove`;
//! - the brand check is unchanged: `get` finds its State through
//!   `Instance.stateAs` first, so an instance of a foreign type - whatever its
//!   bytes say where the live word would be - answers null, and so does a
//!   freed slot (its generation) before its Instance is read
//!   (docs/lessons/architecture-brand-check-the-receiver-once-in-the-binding.md).
//!
//! Blink keeps such facts as bits of the object (Node::node_flags_), not as
//! pointers to the object itself.

const std = @import("std");
const runtime = @import("runtime");

const testing = std.testing;
const BrowserScope = runtime.BrowserScope;

const Owning = struct {
    bytes: ?[]u8 = null,
    pub const embedded_in_state = true;

    pub fn deinit(self: *Owning) void {
        if (self.bytes) |bytes| testing.allocator.free(bytes);
        self.bytes = null;
    }
};
const RootInternal = struct {
    listeners: u32 = 0,
    pub const embedded_in_state = true;
};
/// An impl that keeps no state (`InternalState = struct {}`).
const Empty = struct {};
/// An impl whose state is a block of its own (not embedded).
const Separate = struct { value: u64 = 0 };

// EventTarget <- Node <- Element <- HTMLDivElement, as codegen writes them:
// every level's own fields end with `_internal`.
const RootState = runtime.FlattenedState(null, &.{}, struct {
    flag: u8 = 0,
    _internal: ?*RootInternal = null,
});
const MidState = runtime.FlattenedState(RootState, &.{}, struct {
    cached_child: ?*runtime.Instance = null,
    _internal: ?*Owning = null,
});
const LeafState = runtime.FlattenedState(MidState, &.{}, struct {
    a: u16 = 0,
    _internal: ?*Owning = null,
});
const EmptyLeafState = runtime.FlattenedState(LeafState, &.{}, struct {
    _internal: ?*Empty = null,
});
/// A chain whose levels keep separate blocks: nothing changes for it.
const SeparateState = runtime.FlattenedState(null, &.{}, struct {
    _internal: ?*Separate = null,
});
/// Not on the chain, but with a live word of its own at its root: the brand
/// check rejects it whatever that word holds.
const OtherState = runtime.FlattenedState(null, &.{}, struct {
    _internal: ?*Owning = null,
});

const no_methods = .{};
const leaf_vtable: runtime.VTable = .{ .name = "Leaf", .ancestors = runtime.ancestorsOf(EmptyLeafState), .deinit = null, .methods_ptr = &no_methods };
const mid_vtable: runtime.VTable = .{ .name = "Mid", .ancestors = runtime.ancestorsOf(MidState), .deinit = null, .methods_ptr = &no_methods };
const other_vtable: runtime.VTable = .{ .name = "Other", .ancestors = runtime.ancestorsOf(OtherState), .deinit = null, .methods_ptr = &no_methods };

const RootOwn = runtime.OwnState(RootState, RootInternal);
const MidOwn = runtime.OwnState(MidState, Owning);
const LeafOwn = runtime.OwnState(LeafState, Owning);
const OtherOwn = runtime.OwnState(OtherState, Owning);

fn make(scope: *BrowserScope, comptime State: type, vtable: *const runtime.VTable) !*runtime.Instance {
    const instance = try scope.slab.alloc(vtable);
    const state = try scope.arena.create(State);
    @memset(std.mem.asBytes(state), 0);
    instance.state = state;
    return instance;
}

/// The root's live word (red at the base, which keeps a pointer per level:
/// written so the file compiles there).
fn live(root: anytype) !u32 {
    if (comptime @hasField(@TypeOf(root.*), "_live")) return root._live else return error.NoLiveWord;
}

fn setLive(root: anytype, value: u32) !void {
    if (comptime @hasField(@TypeOf(root.*), "_live")) root._live = value else return error.NoLiveWord;
}

fn hasInternal(comptime State: type) bool {
    return @hasField(@FieldType(State, "own"), "_internal");
}

test "an embedded or empty level keeps no `_internal` pointer; a separate block's level keeps it" {
    try testing.expect(!hasInternal(RootState));
    try testing.expect(!hasInternal(MidState));
    try testing.expect(!hasInternal(LeafState));
    try testing.expect(!hasInternal(EmptyLeafState));
    try testing.expect(hasInternal(SeparateState));
    // The other own fields stay, with their defaults.
    try testing.expect(@hasField(@FieldType(MidState, "own"), "cached_child"));
    try testing.expect(@hasField(@FieldType(RootState, "own"), "flag"));
}

test "the chain's root keeps one live word, and no other level keeps one" {
    try testing.expect(@hasField(RootState, "_live"));
    inline for (.{ MidState, LeafState, EmptyLeafState }) |State| {
        try testing.expect(!@hasField(State, "_live") or @FieldType(State, "_live") == void);
    }
    try testing.expect(!@hasField(SeparateState, "_live") or @FieldType(SeparateState, "_live") == void);
}

test "OwnState: create sets the level's live bit, remove clears it, other levels keep theirs" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const leaf = try make(&scope, EmptyLeafState, &leaf_vtable);
    const state: *EmptyLeafState = @ptrCast(@alignCast(leaf.state));

    try testing.expect(RootOwn.get(leaf) == null and MidOwn.get(leaf) == null and LeafOwn.get(leaf) == null);
    const root = try RootOwn.create(leaf);
    root.listeners = 7;
    const mid = try MidOwn.create(leaf);
    mid.bytes = try testing.allocator.dupe(u8, "mid");
    const own = try LeafOwn.create(leaf);

    try testing.expectEqual(&state.base.base.base._embedded, root);
    try testing.expectEqual(&state.base.base._embedded, mid);
    try testing.expectEqual(&state.base._embedded, own);
    try testing.expectEqual(@as(u32, 0b111), try live(&state.base.base.base));

    MidOwn.get(leaf).?.deinit();
    MidOwn.remove(leaf);
    try testing.expect(MidOwn.get(leaf) == null);
    try testing.expectEqual(@as(u32, 0b101), try live(&state.base.base.base));
    try testing.expectEqual(@as(u32, 7), RootOwn.get(leaf).?.listeners);
    try testing.expectEqual(own, LeafOwn.get(leaf).?);
    MidOwn.remove(leaf); // again: nothing
    LeafOwn.remove(leaf);
    RootOwn.remove(leaf);
    try testing.expectEqual(@as(u32, 0), try live(&state.base.base.base));
}

test "OwnState: a foreign instance answers null whatever its live word holds, and so does a shorter chain" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const other = try make(&scope, OtherState, &other_vtable);
    const mid = try make(&scope, MidState, &mid_vtable);
    // Every bit set where a foreign root keeps its word: the brand check, not
    // the word, answers.
    try setLive(@as(*OtherState, @ptrCast(@alignCast(other.state))), std.math.maxInt(u32));
    try testing.expect(MidOwn.get(other) == null);
    try testing.expect(LeafOwn.get(other) == null);
    try testing.expect(RootOwn.get(other) == null);
    try testing.expect(OtherOwn.get(other) != null); // its own level, its own bit
    try setLive(&@as(*MidState, @ptrCast(@alignCast(mid.state))).base, std.math.maxInt(u32));
    try testing.expect(LeafOwn.get(mid) == null);
    try testing.expect(MidOwn.get(mid) != null);
}

test "OwnState: a freed slot answers null before its Instance is read, and its reissue starts with no level live" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const leaf = try make(&scope, EmptyLeafState, &leaf_vtable);
    _ = try MidOwn.create(leaf);
    scope.slab.free(leaf);
    try testing.expect(MidOwn.get(leaf) == null);
    const again = try make(&scope, EmptyLeafState, &leaf_vtable);
    try testing.expectEqual(leaf, again);
    try testing.expect(MidOwn.get(again) == null and RootOwn.get(again) == null);
}

test "OwnState's count and sweep read the live bits" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var made: [3]*runtime.Instance = undefined;
    for (&made, 0..) |*slot, i| {
        slot.* = try make(&scope, EmptyLeafState, &leaf_vtable);
        (try MidOwn.create(slot.*)).bytes = try std.fmt.allocPrint(testing.allocator, "orphan {d}", .{i});
    }
    MidOwn.get(made[1]).?.deinit();
    MidOwn.remove(made[1]);
    try testing.expectEqual(@as(usize, 2), MidOwn.count(&scope));
    try testing.expectEqual(@as(usize, 2), runtime.ownStateCount(MidState, &scope));
    MidOwn.deinitAllAndClear(&scope);
    try testing.expectEqual(@as(usize, 0), MidOwn.count(&scope));
    try testing.expectEqual(@as(usize, 0), runtime.ownStateCount(MidState, &scope));
}

/// A node-shaped state kept by value: the counted-node predicate
/// (runtime.lifetime.countedOf) finds it with no `_internal` pointer to read.
const FakeNodeBase = struct { rc: u32 = 0 };
const NodeInternal = struct {
    base: FakeNodeBase = .{},
    pub const embedded_in_state = true;
    pub const counted_node = true;
};
const NodeState = runtime.FlattenedState(RootState, &.{}, struct {
    _internal: ?*NodeInternal = null,
});
const ElementState = runtime.FlattenedState(NodeState, &.{}, struct {
    _internal: ?*Owning = null,
});
const delegates = .{};

test "a node level kept by value still makes its State, and every State built on it, counted" {
    const node = comptime runtime.buildVTable(&delegates, "Node", NodeState);
    const element = comptime runtime.buildVTable(&delegates, "Element", ElementState);
    try testing.expect(node.counted != null);
    try testing.expect(element.counted != null);
    const root = comptime runtime.buildVTable(&delegates, "EventTarget", RootState);
    try testing.expect(root.counted == null);
}
