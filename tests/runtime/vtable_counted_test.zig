//! `VTable.counted` (refcount design 2.1, step 4): which types' wrappers own a
//! counted reference. Nodes only (decision D3), found at comptime by
//! `buildVTable` from the State's shape: some level of its `base` chain keeps an
//! `_internal` pointer whose target declares `pub const counted_node = true;`
//! - Node's InternalState, and nothing else's. (It was "has a field named
//! `node_base`" until lane nm1 removed that field from Node's state.)
//!
//! The DEFAULT is pinned here, not only the known case: a type that is not
//! counted keeps today's path (the collector frees it through
//! `gc.onObjectFreed`), and a type wrongly read as counted would hand the
//! adapter a "target" that is not a node. AGENTS.md "Comptime predicates": pin
//! the default.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");

const Instance = runtime.Instance;

/// A node-shaped InternalState: the one declaration the predicate looks for.
const FakeNodeBase = struct { rc: u32 = 0 };
const NodeInternal = struct {
    base: FakeNodeBase = .{},
    pub const counted_node = true;
};
const OtherInternal = struct { value: u32 = 0 };
/// Declared, and false: not counted.
const DeclinedInternal = struct {
    value: u32 = 0,
    pub const counted_node = false;
};
/// The predicate's old key - a field NAMED `node_base` - and no declaration:
/// not counted. A name is not a statement.
const NamedOnlyInternal = struct { node_base: ?*FakeNodeBase = null };

const NodeState = runtime.FlattenedState(null, &.{}, struct {
    nodeType: u16 = 0,
    _internal: ?*NodeInternal = null,
});
const ElementState = runtime.FlattenedState(NodeState, &.{}, struct {
    localName: u16 = 0,
    _internal: ?*OtherInternal = null,
});
const DivState = runtime.FlattenedState(ElementState, &.{}, struct {
    @"align": u16 = 0,
    _internal: ?*OtherInternal = null,
});
const HeadersState = runtime.FlattenedState(null, &.{}, struct {
    guard: u16 = 0,
    _internal: ?*OtherInternal = null,
});
const NoInternalState = runtime.FlattenedState(null, &.{}, struct { x: u8 = 0 });
const DeclinedState = runtime.FlattenedState(null, &.{}, struct {
    _internal: ?*DeclinedInternal = null,
});
const NamedOnlyState = runtime.FlattenedState(null, &.{}, struct {
    _internal: ?*NamedOnlyInternal = null,
});
const OnDeclinedState = runtime.FlattenedState(DeclinedState, &.{}, struct {
    _internal: ?*OtherInternal = null,
});

const delegates = .{};

test "a hand-written VTable is not counted: the default is null" {
    const vtable: runtime.VTable = .{ .name = "Mock", .deinit = null, .methods_ptr = @ptrCast(&delegates) };
    try testing.expect(vtable.counted == null);
}

test "buildVTable: a State with no node level is not counted" {
    const headers = comptime runtime.buildVTable(&delegates, "Headers", HeadersState);
    try testing.expect(headers.counted == null);
    const bare = comptime runtime.buildVTable(&delegates, "Bare", NoInternalState);
    try testing.expect(bare.counted == null);
    const plain = comptime runtime.buildVTable(&delegates, "Plain", struct { a: u32 });
    try testing.expect(plain.counted == null);
}

test "buildVTable: the predicate's default is not counted - no declaration, a false one, or only the old field name" {
    // tests/AGENTS.md "Comptime predicates": the default, both ways.
    const declined = comptime runtime.buildVTable(&delegates, "Declined", DeclinedState);
    try testing.expect(declined.counted == null);
    const on_declined = comptime runtime.buildVTable(&delegates, "OnDeclined", OnDeclinedState);
    try testing.expect(on_declined.counted == null);
    const named_only = comptime runtime.buildVTable(&delegates, "NamedOnly", NamedOnlyState);
    try testing.expect(named_only.counted == null);
    try testing.expect((comptime runtime.lifetime.countedOf(HeadersState)) == null);
    try testing.expect((comptime runtime.lifetime.countedOf(NodeState)) != null);
}

test "buildVTable: a node's State, and every State built on it, is counted" {
    const node = comptime runtime.buildVTable(&delegates, "Node", NodeState);
    const div = comptime runtime.buildVTable(&delegates, "HTMLDivElement", DivState);
    try testing.expect(node.counted != null);
    try testing.expect(div.counted != null);
    // One table for every counted type: the runtime dispatches, the owner of
    // the counts (dom.refcount) decides.
    try testing.expectEqual(node.counted.?, div.counted.?);
}

test "lifetime: a type that is not counted has no target, and nothing is told" {
    var observed: usize = 0;
    const Observer = struct {
        var calls: *usize = undefined;
        fn acquire(_: *Instance) ?*anyopaque {
            calls.* += 1;
            return null;
        }
        fn release(_: *anyopaque) void {
            calls.* += 1;
        }
    };
    Observer.calls = &observed;
    const override = runtime.lifetime.overrideHooksForTest(.{ .acquire = Observer.acquire, .release = Observer.release });
    defer override.restore();

    const headers = comptime runtime.buildVTable(&delegates, "Headers", HeadersState);
    var instance: Instance = .{ .vtable = &headers, .state = undefined, .ctx = undefined };
    try testing.expect(runtime.lifetime.wrapperAcquired(&instance) == null);
    try testing.expectEqual(@as(usize, 0), observed);
}

test "lifetime: a counted type's acquire and release reach the owner's hooks with the target" {
    const Observer = struct {
        var target: FakeNodeBase = .{};
        var acquired: usize = 0;
        var released: usize = 0;
        fn acquire(_: *Instance) ?*anyopaque {
            acquired += 1;
            target.rc += 2;
            return &target;
        }
        fn release(raw: *anyopaque) void {
            released += 1;
            const node: *FakeNodeBase = @ptrCast(@alignCast(raw));
            node.rc -= 2;
        }
    };
    // Its counters are the test's statics: a second run in the same process
    // (verify mode runs it ten times in one) starts them from zero again.
    Observer.target = .{};
    Observer.acquired = 0;
    Observer.released = 0;
    const override = runtime.lifetime.overrideHooksForTest(.{ .acquire = Observer.acquire, .release = Observer.release });
    defer override.restore();

    const div = comptime runtime.buildVTable(&delegates, "HTMLDivElement", DivState);
    var instance: Instance = .{ .vtable = &div, .state = undefined, .ctx = undefined };
    const target = runtime.lifetime.wrapperAcquired(&instance) orelse return error.NotCounted;
    try testing.expectEqual(@as(*anyopaque, &Observer.target), target);
    try testing.expectEqual(@as(u32, 2), Observer.target.rc);
    runtime.lifetime.wrapperReleased(target);
    try testing.expectEqual(@as(u32, 0), Observer.target.rc);
    try testing.expectEqual(@as(usize, 1), Observer.acquired);
    try testing.expectEqual(@as(usize, 1), Observer.released);
}

test "lifetime: with no owner installed, a counted type takes no reference" {
    const override = runtime.lifetime.overrideHooksForTest(.{});
    defer override.restore();
    const div = comptime runtime.buildVTable(&delegates, "HTMLDivElement", DivState);
    var instance: Instance = .{ .vtable = &div, .state = undefined, .ctx = undefined };
    try testing.expect(runtime.lifetime.wrapperAcquired(&instance) == null);
}
