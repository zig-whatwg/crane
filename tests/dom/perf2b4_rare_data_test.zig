//! A node's rare data and the intrusive registered observer list (lane perf2
//! batch 4, R6 part 1; tmp/plans/perf2b4-design.md).
//!
//! - A node that never needs rare data has none, and costs no allocation.
//! - What a caller holds never moves: a registered observer's record and the
//!   list's head are blocks of their own (Blink 601c5205e1d5: rare data that
//!   reallocated left a caller holding a stale pointer into it). The rare
//!   block itself is the node's one sparse block since lane nm2 and MAY move
//!   when a field is added (tests/dom/nm2_one_rare_block_test.zig).
//! - DOM 4.3's registered observer list is a list: entries come back in the
//!   order they were appended, a removed entry leaves the others in order,
//!   and a walk may remove the entry it was just given.
//! - The node's teardown (NodeBase.deinitRareData) frees what it owns: an
//!   owned node name and the block; std.testing.allocator sees the rest.
//!
//! The nodes are real ones with no node document (real_nodes.zig `bare`;
//! lane wb1): an Element's node block, whose allocator is its Browser's. They
//! were NodeBase values on the test's stack.

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const real_nodes = @import("real_nodes.zig");

const NodeBase = dom.NodeBase;
const RegisteredObserver = dom.node_base.RegisteredObserverType;

/// Three distinct observers, never dereferenced: a registration names its
/// observer by address only.
const Observers = struct {
    slots: [3]u64 = .{ 0, 0, 0 },

    fn registration(self: *Observers, index: usize, subtree: bool) RegisteredObserver {
        return RegisteredObserver.initFromPtr(@ptrCast(&self.slots[index]), .{ .attributes = true, .subtree = subtree });
    }

    fn indexOf(self: *const Observers, registered: *const RegisteredObserver) usize {
        return (@intFromPtr(registered.getObserverPtr()) - @intFromPtr(&self.slots[0])) / @sizeOf(u64);
    }

    fn expectOrder(self: *const Observers, node: *const NodeBase, expected: []const usize) !void {
        var seen: [8]usize = undefined;
        var count: usize = 0;
        var entries = node.registeredObservers();
        while (entries.next()) |registered| : (count += 1) seen[count] = self.indexOf(registered);
        try testing.expectEqualSlices(usize, expected, seen[0..count]);
    }
};

test "a node that never needs rare data has none" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const node = try nodes.bare(.element);
    try testing.expect(node.rare.block == null);
    try testing.expectEqualStrings("", node.nodeName());
    try testing.expect(!node.hasOwnedNodeName());
    try testing.expect(!node.hasRegisteredObservers());
    var entries = node.registeredObservers();
    try testing.expect(entries.next() == null);
    node.deinitRareData();
    try testing.expect(node.rare.block == null);
}

test "the list's head is made once and never moves; the list keeps registration order" {
    var observers: Observers = .{};
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    // The Browser's end releases the node, and its rare data with it.
    defer nodes.close();
    const node = try nodes.bare(.element);

    const first = try node.appendRegisteredObserver(observers.registration(0, false));
    const rare = dom.node_rare_data.get(node.rare, .registered_observers).?;
    const second = try node.appendRegisteredObserver(observers.registration(1, true));
    const third = try node.appendRegisteredObserver(observers.registration(2, false));
    try testing.expectEqual(rare, dom.node_rare_data.get(node.rare, .registered_observers).?);
    try observers.expectOrder(node, &.{ 0, 1, 2 });

    // observe() step 7.2: the entry is updated where it is.
    first.options = .{ .child_list = true };
    try observers.expectOrder(node, &.{ 0, 1, 2 });
    try testing.expect(first.options.child_list);

    // A transient copy is appended like any other entry.
    var transient = observers.registration(0, true);
    transient.transient_source = &observers.slots;
    _ = try node.appendRegisteredObserver(transient);
    try observers.expectOrder(node, &.{ 0, 1, 2, 0 });

    // Removing from the middle leaves the rest in order; the head stays.
    node.removeRegisteredObserver(second);
    try observers.expectOrder(node, &.{ 0, 2, 0 });
    try testing.expectEqual(rare, dom.node_rare_data.get(node.rare, .registered_observers).?);

    // A walk may remove the entry it was just given (disconnect(), the
    // transient removal of notify step 6.3, the node's teardown).
    var entries = node.registeredObservers();
    while (entries.next()) |registered| {
        if (registered.transient_source != null) node.removeRegisteredObserver(registered);
    }
    try observers.expectOrder(node, &.{ 0, 2 });
    node.removeRegisteredObserver(third);
    node.removeRegisteredObserver(first);
    try testing.expect(!node.hasRegisteredObservers());
    try testing.expectEqual(rare, dom.node_rare_data.get(node.rare, .registered_observers).?);
}

test "the node name lives in rare data, and an owned one is freed with it" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const node = try nodes.bare(.element);

    try node.setStaticNodeName("EMBED");
    try testing.expectEqualStrings("EMBED", node.nodeName());
    try testing.expect(!node.hasOwnedNodeName());

    // setLocalName's uppercase copy: owned by the node from here.
    const owned = try node.allocator().dupe(u8, "SCRIPT");
    try node.setOwnedNodeName(owned);
    try testing.expectEqualStrings("SCRIPT", node.nodeName());
    try testing.expect(node.hasOwnedNodeName());

    // Renaming frees the owned name it replaces.
    try node.setOwnedNodeName(try node.allocator().dupe(u8, "IFRAME"));
    try testing.expectEqualStrings("IFRAME", node.nodeName());

    node.deinitRareData();
    try testing.expect(node.rare.block == null);
    try testing.expectEqualStrings("", node.nodeName());
}
