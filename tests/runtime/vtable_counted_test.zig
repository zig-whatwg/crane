//! `VTable.counted` (refcount design 2.1, step 4): which types' wrappers own a
//! counted reference. Nodes only (decision D3), found at comptime by
//! `buildVTable` from the State's shape: some level of its `base` chain keeps an
//! `_internal` pointer whose target has a `node_base` field - Node's
//! InternalState, and nothing else's.
//!
//! The DEFAULT is pinned here, not only the known case: a type that is not
//! counted keeps today's path (the collector frees it through
//! `gc.onObjectFreed`), and a type wrongly read as counted would hand the
//! adapter a "target" that is not a node. AGENTS.md "Comptime predicates": pin
//! the default.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");

/// A node-shaped InternalState: the one field the predicate looks for.
const FakeNodeBase = struct { rc: u32 = 0 };
const NodeInternal = struct { node_base: ?*FakeNodeBase = null };
const OtherInternal = struct { value: u32 = 0 };

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

test "buildVTable: a node's State, and every State built on it, is counted" {
    const node = comptime runtime.buildVTable(&delegates, "Node", NodeState);
    const div = comptime runtime.buildVTable(&delegates, "HTMLDivElement", DivState);
    try testing.expect(node.counted != null);
    try testing.expect(div.counted != null);
    // One table for every counted type: the runtime dispatches, the owner of
    // the counts (dom.refcount) decides.
    try testing.expectEqual(node.counted.?, div.counted.?);
}
