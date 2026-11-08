//! NodeRareData and the intrusive registered observer list (lane perf2 batch
//! 4, R6 part 1; tmp/plans/perf2b4-design.md).
//!
//! - A node that never needs rare data has none, and costs no allocation.
//! - Rare data is made once, on first use, and never moves (Blink
//!   601c5205e1d5: rare data that reallocated left a caller holding a stale
//!   pointer into it).
//! - DOM 4.3's registered observer list is a list: entries come back in the
//!   order they were appended, a removed entry leaves the others in order,
//!   and a walk may remove the entry it was just given.
//! - The node's teardown (NodeBase.deinitRareData) frees what it owns: an
//!   owned node name and the block; std.testing.allocator sees the rest.

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const infra = @import("infra");

const NodeBase = dom.NodeBase;
const RegisteredObserver = dom.node_base.RegisteredObserverType;

fn bareNode() NodeBase {
    return .{
        .owner = NodeBase.ownerless(&std.testing.allocator),
        .node_type = NodeBase.ELEMENT_NODE,
    };
}

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
    var node = bareNode();
    try testing.expect(node.rareData() == null);
    try testing.expectEqualStrings("", node.nodeName());
    try testing.expect(!node.hasOwnedNodeName());
    try testing.expect(!node.hasRegisteredObservers());
    var entries = node.registeredObservers();
    try testing.expect(entries.next() == null);
    node.deinitRareData();
    try testing.expect(node.rareData() == null);
}

test "rare data is made once and never moves; the list keeps registration order" {
    var observers: Observers = .{};
    var node = bareNode();
    defer node.deinitRareData();

    const first = try node.appendRegisteredObserver(observers.registration(0, false));
    const rare = node.rareData().?;
    const second = try node.appendRegisteredObserver(observers.registration(1, true));
    const third = try node.appendRegisteredObserver(observers.registration(2, false));
    try testing.expectEqual(rare, node.rareData().?);
    try observers.expectOrder(&node, &.{ 0, 1, 2 });

    // observe() step 7.2: the entry is updated where it is.
    first.options = .{ .child_list = true };
    try observers.expectOrder(&node, &.{ 0, 1, 2 });
    try testing.expect(first.options.child_list);

    // A transient copy is appended like any other entry.
    var transient = observers.registration(0, true);
    transient.transient_source = &observers.slots;
    _ = try node.appendRegisteredObserver(transient);
    try observers.expectOrder(&node, &.{ 0, 1, 2, 0 });

    // Removing from the middle leaves the rest in order; the block stays.
    node.removeRegisteredObserver(second);
    try observers.expectOrder(&node, &.{ 0, 2, 0 });
    try testing.expectEqual(rare, node.rareData().?);

    // A walk may remove the entry it was just given (disconnect(), the
    // transient removal of notify step 6.3, the node's teardown).
    var entries = node.registeredObservers();
    while (entries.next()) |registered| {
        if (registered.transient_source != null) node.removeRegisteredObserver(registered);
    }
    try observers.expectOrder(&node, &.{ 0, 2 });
    node.removeRegisteredObserver(third);
    node.removeRegisteredObserver(first);
    try testing.expect(!node.hasRegisteredObservers());
    try testing.expectEqual(rare, node.rareData().?);
}

test "the node name lives in rare data, and an owned one is freed with it" {
    var node = bareNode();

    try node.setStaticNodeName("EMBED");
    try testing.expectEqualStrings("EMBED", node.nodeName());
    try testing.expect(!node.hasOwnedNodeName());

    // setLocalName's uppercase copy: owned by the node from here.
    const owned = try testing.allocator.dupe(u8, "SCRIPT");
    try node.setOwnedNodeName(owned);
    try testing.expectEqualStrings("SCRIPT", node.nodeName());
    try testing.expect(node.hasOwnedNodeName());

    // Renaming frees the owned name it replaces.
    try node.setOwnedNodeName(try testing.allocator.dupe(u8, "IFRAME"));
    try testing.expectEqualStrings("IFRAME", node.nodeName());

    node.deinitRareData();
    try testing.expect(node.rareData() == null);
    try testing.expectEqualStrings("", node.nodeName());
}
