//! A State that does not nest its base interface's State (lane nm3 batch 3,
//! item c; tmp/redesign/node-memory-plan-v2.md X2 and I1).
//!
//! Every node's State nested EventTarget's: the event listener list's
//! address and the chain's live word, 16 bytes on every node, where nearly
//! no node has a listener. For that to go, three things the runtime assumed
//! must hold without the nesting:
//!
//! - the ANCESTRY is still the interface's whole inheritance chain - an
//!   instance of the derived interface implements the base one, which is
//!   what the binding's brand check asks (`Instance.implements`) - while
//!   `Instance.stateAs` answers null for the State that is not there;
//! - each level's "is my state made" bit needs a home: the root level's own
//!   state keeps the chain's bits when it says so (`LiveBits`, `liveBits`),
//!   in bytes it already has;
//! - the base interface's impl must allow it (`may_be_absent`): it is the
//!   one that reads that State.
//!
//! The fixtures are shaped as codegen writes a State: every level's own
//! fields end with `_internal`. They compile at the base, where the
//! declarations are unread and the tests fail.

const std = @import("std");
const runtime = @import("runtime");

const testing = std.testing;
const BrowserScope = runtime.BrowserScope;

/// The base interface's state (EventTarget's shape): one word, and it lets
/// a derived State leave it out.
const BaseInternal = struct {
    listeners: usize = 0,
    pub const embedded_in_state = true;
    pub const may_be_absent = true;
};

/// A node-shaped block with a spare byte for the chain's live bits.
const FakeNodeBase = extern struct {
    link: usize = 0,
    node_type: u8 = 0,
    live: u8 = 0,
    flags: [6]u8 = @splat(0),
};

/// The derived interface's state (Node's shape): it does not nest its
/// base's State, and keeps the chain's live bits itself.
const HostInternal = struct {
    base: FakeNodeBase = .{},
    pub const embedded_in_state = true;
    pub const omits_base_state = true;
    pub const LiveBits = u8;

    pub inline fn liveBits(self: *HostInternal) *LiveBits {
        return &self.base.live;
    }
};

const Owning = struct {
    bytes: ?[]u8 = null,
    pub const embedded_in_state = true;

    pub fn deinit(self: *Owning) void {
        if (self.bytes) |bytes| testing.allocator.free(bytes);
        self.bytes = null;
    }
};

const BaseState = runtime.FlattenedState(null, &.{}, struct {
    _internal: ?*BaseInternal = null,
});
const HostState = runtime.FlattenedState(BaseState, &.{}, struct {
    _internal: ?*HostInternal = null,
});
const LeafState = runtime.FlattenedState(HostState, &.{}, struct {
    _internal: ?*Owning = null,
});

/// Whether this build lets a State leave its base's out.
const omits = @FieldType(HostState, "base") == void;
const has_implements = @hasDecl(runtime.Instance, "implements");

const no_methods = .{};
const base_vtable: runtime.VTable = .{ .name = "Base", .ancestors = runtime.ancestorsOf(BaseState), .deinit = null, .methods_ptr = &no_methods };
const leaf_vtable: runtime.VTable = .{ .name = "Leaf", .ancestors = runtime.ancestorsOf(LeafState), .deinit = null, .methods_ptr = &no_methods };

const BaseOwn = runtime.OwnState(BaseState, BaseInternal);
const HostOwn = runtime.OwnState(HostState, HostInternal);
const LeafOwn = runtime.OwnState(LeafState, Owning);

fn make(scope: *BrowserScope, comptime State: type, vtable: *const runtime.VTable) !*runtime.Instance {
    const instance = try scope.slab.alloc(vtable);
    const state = try scope.arena.create(State);
    @memset(std.mem.asBytes(state), 0);
    instance.state = state;
    return instance;
}

test "a State whose impl omits its base's State starts at its own level and keeps no live word of its own" {
    if (comptime !omits) return error.BaseStateStillNested;
    // The base's 8 bytes and the 4-byte live word (8 with its padding) are
    // gone: the State is the impl's own state and nothing else.
    try testing.expectEqual(@sizeOf(HostInternal), @sizeOf(HostState));
    try testing.expectEqual(@as(usize, 16), @sizeOf(HostState));
    try testing.expect(@FieldType(HostState, "_live") == void);
    try testing.expectEqual(@as(usize, 0), @offsetOf(HostState, "_embedded"));
    // A State that nests its base is as it was.
    try testing.expect(@FieldType(LeafState, "base") == HostState);
    try testing.expect(@FieldType(BaseState, "_live") != void);
}

test "the ancestry still lists the base interface, with no bytes behind it" {
    if (comptime !omits) return error.BaseStateStillNested;
    const ancestors = runtime.ancestorsOf(LeafState);
    try testing.expectEqual(@as(usize, 3), ancestors.len);
    try testing.expectEqual(runtime.typeId(LeafState), ancestors[0].id);
    try testing.expectEqual(runtime.typeId(HostState), ancestors[1].id);
    try testing.expectEqual(runtime.typeId(BaseState), ancestors[2].id);
    try testing.expectEqual(@as(usize, 0), ancestors[0].offset);
    try testing.expectEqual(@offsetOf(LeafState, "base"), ancestors[1].offset);
    try testing.expectEqual(@as(usize, std.math.maxInt(usize)), ancestors[2].offset);
}

test "an instance implements the base interface it keeps no State of, and stateAs answers null for it" {
    if (comptime !omits) return error.BaseStateStillNested;
    if (comptime !has_implements) return error.NoImplements;
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const leaf = try make(&scope, LeafState, &leaf_vtable);
    const base = try make(&scope, BaseState, &base_vtable);

    try testing.expect(leaf.implements(BaseState));
    try testing.expect(leaf.implements(HostState));
    try testing.expect(leaf.implements(LeafState));
    try testing.expect(leaf.stateAs(BaseState) == null);
    try testing.expect(leaf.stateAs(HostState) != null);
    try testing.expect(leaf.stateAs(LeafState) != null);
    // The base impl's own reader answers "no state here", never the bytes
    // of another level.
    try testing.expect(BaseOwn.get(leaf) == null);
    try testing.expectError(error.InvalidStateError, BaseOwn.create(leaf));

    // An instance of the base interface itself has its State as before, and
    // is no instance of the derived ones.
    try testing.expect(base.implements(BaseState));
    try testing.expect(base.stateAs(BaseState) != null);
    try testing.expect(!base.implements(HostState));
    try testing.expect(!base.implements(LeafState));
    try testing.expect(base.stateAs(HostState) == null);
    _ = try BaseOwn.create(base);
    try testing.expect(BaseOwn.get(base) != null);
    BaseOwn.remove(base);
}

test "the chain's live bits are the root level's own: create sets a level's bit there, remove clears it" {
    if (comptime !omits) return error.BaseStateStillNested;
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const leaf = try make(&scope, LeafState, &leaf_vtable);
    const state: *LeafState = @ptrCast(@alignCast(leaf.state));
    const node = &state.base._embedded.base;

    try testing.expect(HostOwn.get(leaf) == null and LeafOwn.get(leaf) == null);
    const host = try HostOwn.create(leaf);
    try testing.expectEqual(&state.base._embedded, host);
    // The host's level is the chain's root: bit 0.
    try testing.expectEqual(@as(u8, 0b01), node.live);
    const own = try LeafOwn.create(leaf);
    own.bytes = try testing.allocator.dupe(u8, "leaf");
    try testing.expectEqual(@as(u8, 0b11), node.live);
    // Nothing else of the block moved.
    try testing.expectEqual(@as(u8, 0), node.node_type);

    try testing.expectEqual(@as(usize, 1), HostOwn.count(&scope));
    try testing.expectEqual(@as(usize, 1), runtime.ownStateCount(LeafState, &scope));

    LeafOwn.get(leaf).?.deinit();
    LeafOwn.remove(leaf);
    try testing.expectEqual(@as(u8, 0b01), node.live);
    try testing.expect(LeafOwn.get(leaf) == null and HostOwn.get(leaf) != null);
    HostOwn.remove(leaf);
    try testing.expectEqual(@as(u8, 0), node.live);
    try testing.expect(HostOwn.get(leaf) == null);
}

test "a sweep finds the states no deinit reached by the root level's bits" {
    if (comptime !omits) return error.BaseStateStillNested;
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var made: [3]*runtime.Instance = undefined;
    for (&made, 0..) |*slot, i| {
        slot.* = try make(&scope, LeafState, &leaf_vtable);
        _ = try HostOwn.create(slot.*);
        (try LeafOwn.create(slot.*)).bytes = try std.fmt.allocPrint(testing.allocator, "orphan {d}", .{i});
    }
    LeafOwn.get(made[1]).?.deinit();
    LeafOwn.remove(made[1]);
    try testing.expectEqual(@as(usize, 2), LeafOwn.count(&scope));
    LeafOwn.deinitAllAndClear(&scope);
    try testing.expectEqual(@as(usize, 0), LeafOwn.count(&scope));
    try testing.expectEqual(@as(usize, 3), HostOwn.count(&scope));
}
