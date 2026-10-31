//! The reference counting types (lane rc12, step 2 of
//! tmp/plans/refcount-design.md): the count word, `subtree_holds` (decision D1
//! as arithmetic), `Ref`, `GCReachableRef`, `WeakRef`, the Debug ledger (D9:
//! these tests run it in `.log` mode where they provoke a violation, so the
//! violation is counted instead of fatal) and the underflow checks.
//!
//! Nodes here are bare NodeBase values linked by hand: the count machinery
//! needs no runtime and no engine. `std.testing.allocator` sees every
//! allocation, the ledger's included.
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const runtime = @import("runtime");
const refcount = dom.refcount;
const NodeBase = dom.NodeBase;

fn newNode(allocator: std.mem.Allocator) !*NodeBase {
    const node = try allocator.create(NodeBase);
    node.* = .{
        .allocator = allocator,
        .node_type = NodeBase.ELEMENT_NODE,
        .node_name = "div",
        .child_nodes = .init(allocator),
        .registered_observers = .init(allocator),
    };
    return node;
}

/// A tree made of bare nodes and the ledger counting them.
const Fixture = struct {
    ledger: refcount.Ledger,
    nodes: std.ArrayList(*NodeBase) = .empty,
    garbage: std.ArrayList(*NodeBase) = .empty,

    fn init(fixture: *Fixture, mode: refcount.Mode) void {
        fixture.* = .{
            .ledger = refcount.Ledger.init(testing.allocator, .{
                .mode = mode,
                .on_garbage = .{ .context = fixture, .push = pushGarbage },
                // A violation a test provokes is the one it asked for: an error
                // log would fail the test.
                .report = quiet,
            }),
        };
    }

    fn deinit(fixture: *Fixture) void {
        // Frees the ledger's books (leaks, if any, are reported by `finish`).
        _ = fixture.ledger.finish();
        for (fixture.nodes.items) |node| testing.allocator.destroy(node);
        fixture.nodes.deinit(testing.allocator);
        fixture.garbage.deinit(testing.allocator);
    }

    fn quiet(_: []const u8) void {}

    fn pushGarbage(context: ?*anyopaque, root: *NodeBase) void {
        const fixture: *Fixture = @ptrCast(@alignCast(context.?));
        fixture.garbage.append(testing.allocator, root) catch @panic("oom");
    }

    /// A node and the reference it was born with, adopted.
    fn born(fixture: *Fixture) !refcount.Ref(NodeBase) {
        const node = try newNode(testing.allocator);
        try fixture.nodes.append(testing.allocator, node);
        return refcount.Ref(NodeBase).adopt(&fixture.ledger, node);
    }

    /// What step 3's insert does for a subtree: link, set the parent bit, move
    /// the subtree's holds onto the new chain.
    fn link(fixture: *Fixture, child: *NodeBase, parent: *NodeBase) void {
        child.parent_node = parent;
        refcount.setParentBit(child, true);
        refcount.moveHolds(&fixture.ledger, child, null, parent);
    }

    /// And its remove.
    fn unlink(fixture: *Fixture, child: *NodeBase) void {
        const parent = child.parent_node.?;
        child.parent_node = null;
        refcount.setParentBit(child, false);
        refcount.moveHolds(&fixture.ledger, child, parent, null);
    }
};

test "NodeBase is 456 bytes: 448 before the counts, plus 8 until nodeholds' `holds` is deleted (step 9b), when it returns to 448" {
    // 440 bytes before NodeBase.is_shadow_host, 448 since lane nodeholds' hold
    // chain head (`holds`, a pointer: the padding beside node_type and the
    // bools was 3 bytes), and 456 with `rc` and `subtree_holds` (8 bytes that
    // cannot fit that padding), the integrator's decision of 2026-10-09 (A).
    // Step 9b of tmp/plans/refcount-design.md deletes `holds` and pins 448.
    // Zig 0.17's std.ArrayList carries a `pointer_stability` SafetyLock, a
    // word under runtime safety (Debug, ReleaseSafe) and nothing otherwise;
    // NodeBase reaches two (child_nodes' and registered_observers' heap
    // lists), so a safe build adds two words to Crane's own 456.
    try testing.expectEqual(@as(usize, 456) + 2 * @sizeOf(std.debug.SafetyLock), @sizeOf(NodeBase));
}

test "a node is born with one reference and one hold" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var creator = try fixture.born();
    const node = creator.get();
    try testing.expectEqual(@as(u32, 1), refcount.count(node));
    try testing.expectEqual(@as(u32, 1), node.subtree_holds);
    try testing.expect(!refcount.hasParentBit(node));
    try testing.expect(refcount.isHeld(node));
    try testing.expectEqual(@as(usize, 1), fixture.ledger.outstanding());
    creator.release(&fixture.ledger);
    // The only hold of a one-node tree is gone: the tree is garbage.
    try testing.expectEqual(@as(u32, 0), node.subtree_holds);
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
    try testing.expectEqual(node, fixture.garbage.items[0]);
    try testing.expect(node.rc_flags.garbage);
    try testing.expectEqual(@as(usize, 0), fixture.ledger.finish());
}

test "retain and release count; a hold appears at 0 to 1 and ends at 1 to 0" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var root_ref = try fixture.born();
    var child_ref = try fixture.born();
    const root = root_ref.get();
    const child = child_ref.get();
    fixture.link(child, root);
    try testing.expectEqual(@as(u32, 2), root.subtree_holds);
    try testing.expect(refcount.hasParentBit(child));

    // A second reference to the child changes the count, not the holds.
    var again = child_ref.clone(&fixture.ledger);
    try testing.expectEqual(@as(u32, 2), refcount.count(child));
    try testing.expectEqual(@as(u32, 2), root.subtree_holds);
    again.release(&fixture.ledger);
    try testing.expectEqual(@as(u32, 1), refcount.count(child));
    try testing.expectEqual(@as(u32, 2), root.subtree_holds);

    child_ref.release(&fixture.ledger);
    try testing.expectEqual(@as(u32, 0), refcount.count(child));
    try testing.expectEqual(@as(u32, 0), child.subtree_holds);
    try testing.expectEqual(@as(u32, 1), root.subtree_holds);
    try testing.expectEqual(@as(usize, 0), fixture.garbage.items.len);

    // A new reference to a child that nothing held makes it a hold again.
    var back = refcount.Ref(NodeBase).retain(&fixture.ledger, child);
    try testing.expectEqual(@as(u32, 1), child.subtree_holds);
    try testing.expectEqual(@as(u32, 2), root.subtree_holds);
    back.release(&fixture.ledger);
    root_ref.release(&fixture.ledger);
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
    try testing.expectEqual(@as(usize, 0), fixture.ledger.finish());
}

test "D1: a held descendant keeps its whole tree, and the tree goes when the last hold does" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var a = try fixture.born();
    var b = try fixture.born();
    var c = try fixture.born();
    var sibling = try fixture.born();
    fixture.link(b.get(), a.get());
    fixture.link(c.get(), b.get());
    fixture.link(sibling.get(), a.get());
    try testing.expectEqual(@as(u32, 4), a.get().subtree_holds);
    try testing.expectEqual(@as(u32, 2), b.get().subtree_holds);

    // Everyone but the deepest node lets go: the ancestors have no hold of
    // their own, and the tree is alive because c is held.
    a.release(&fixture.ledger);
    b.release(&fixture.ledger);
    sibling.release(&fixture.ledger);
    try testing.expectEqual(@as(u32, 1), a.get().subtree_holds);
    try testing.expectEqual(@as(usize, 0), fixture.garbage.items.len);
    try testing.expect(!a.get().rc_flags.garbage);

    // The last hold goes: the whole tree is garbage, queued once, by its root.
    c.release(&fixture.ledger);
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
    try testing.expectEqual(a.get(), fixture.garbage.items[0]);
    try testing.expect(a.get().rc_flags.garbage);
    try testing.expect(!b.get().rc_flags.garbage);
}

test "removing a subtree moves its holds; a tree nothing holds is garbage at once, a held subtree stays" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var root_ref = try fixture.born();
    var branch_ref = try fixture.born();
    var leaf_ref = try fixture.born();
    var other_ref = try fixture.born();
    const root = root_ref.get();
    const branch = branch_ref.get();
    fixture.link(branch, root);
    fixture.link(leaf_ref.get(), branch);
    fixture.link(other_ref.get(), root);
    leaf_ref.release(&fixture.ledger);
    branch_ref.release(&fixture.ledger);
    // root holds itself and `other`; branch holds nothing.
    try testing.expectEqual(@as(u32, 2), root.subtree_holds);
    try testing.expectEqual(@as(u32, 0), branch.subtree_holds);

    // innerHTML's case: removing a subtree that holds nothing changes no total
    // of the old tree, and the removed subtree is garbage at once.
    fixture.unlink(branch);
    try testing.expectEqual(@as(u32, 2), root.subtree_holds);
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
    try testing.expectEqual(branch, fixture.garbage.items[0]);

    // The old tree's holds go with its last hold.
    other_ref.release(&fixture.ledger);
    root_ref.release(&fixture.ledger);
    try testing.expectEqual(@as(usize, 2), fixture.garbage.items.len);
    try testing.expectEqual(root, fixture.garbage.items[1]);
}

test "a held subtree moved between trees takes its holds with it" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var old_ref = try fixture.born();
    var new_ref = try fixture.born();
    var moved_ref = try fixture.born();
    var inner_ref = try fixture.born();
    const old_root = old_ref.get();
    const new_root = new_ref.get();
    const moved = moved_ref.get();
    fixture.link(moved, old_root);
    fixture.link(inner_ref.get(), moved);
    try testing.expectEqual(@as(u32, 3), old_root.subtree_holds);
    old_ref.release(&fixture.ledger);
    moved_ref.release(&fixture.ledger);
    // Only inner holds the old tree now.
    try testing.expectEqual(@as(u32, 1), old_root.subtree_holds);

    fixture.unlink(moved);
    try testing.expectEqual(@as(u32, 0), old_root.subtree_holds);
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
    try testing.expectEqual(old_root, fixture.garbage.items[0]);
    fixture.link(moved, new_root);
    try testing.expectEqual(@as(u32, 2), new_root.subtree_holds);
    new_ref.release(&fixture.ledger);
    inner_ref.release(&fixture.ledger);
    try testing.expectEqual(@as(usize, 2), fixture.garbage.items.len);
    try testing.expectEqual(new_root, fixture.garbage.items[1]);
}

/// A shadow root's host, by a table: the hook step 3 installs for real.
const HostTable = struct {
    var shadow: ?*NodeBase = null;
    var host: ?*NodeBase = null;
    fn hostOf(root: *NodeBase) ?*NodeBase {
        if (root == shadow) return host;
        return null;
    }
};

test "the chain is host-including: a hold in a shadow tree keeps its host's tree" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    fixture.ledger.options.host_of = HostTable.hostOf;
    defer fixture.deinit();
    var host_ref = try fixture.born();
    var shadow_ref = try fixture.born();
    var inner_ref = try fixture.born();
    HostTable.host = host_ref.get();
    HostTable.shadow = shadow_ref.get();
    defer {
        HostTable.host = null;
        HostTable.shadow = null;
    }
    // Attaching the shadow root joins its holds to the host's chain, as an
    // insertion does: the shadow root has no parent, its host is its
    // host-including parent.
    refcount.moveHolds(&fixture.ledger, shadow_ref.get(), null, host_ref.get());
    try testing.expectEqual(@as(u32, 2), host_ref.get().subtree_holds);
    fixture.link(inner_ref.get(), shadow_ref.get());
    try testing.expectEqual(@as(u32, 2), shadow_ref.get().subtree_holds);
    try testing.expectEqual(@as(u32, 3), host_ref.get().subtree_holds);
    shadow_ref.release(&fixture.ledger);
    // The shadow root's own hold went; inner still holds the shadow tree and
    // so its host's.
    try testing.expectEqual(@as(u32, 2), host_ref.get().subtree_holds);
    try testing.expectEqual(@as(usize, 0), fixture.garbage.items.len);
    host_ref.release(&fixture.ledger);
    try testing.expectEqual(@as(u32, 1), host_ref.get().subtree_holds);
    try testing.expectEqual(@as(usize, 0), fixture.garbage.items.len);
    inner_ref.release(&fixture.ledger);
    // The last hold of the host-including tree went: the host is the root, and
    // it is garbage.
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
    try testing.expectEqual(HostTable.host.?, fixture.garbage.items[0]);
}

test "underflow: a deref at zero is a violation, and changes nothing" {
    var fixture: Fixture = undefined;
    fixture.init(.log);
    defer fixture.deinit();
    var creator = try fixture.born();
    const node = creator.get();
    creator.release(&fixture.ledger);
    try testing.expectEqual(@as(u64, 0), fixture.ledger.violations);
    refcount.deref(&fixture.ledger, node);
    try testing.expectEqual(@as(u64, 1), fixture.ledger.violations);
    try testing.expectEqual(@as(u32, 0), refcount.count(node));
    try testing.expectEqual(@as(u32, 0), node.subtree_holds);
    // Not queued a second time.
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
}

test "a second release of one Ref is a violation and does not deref again" {
    if (!refcount.tracking) return error.SkipZigTest;
    var fixture: Fixture = undefined;
    fixture.init(.log);
    defer fixture.deinit();
    var first = try fixture.born();
    var second = first.clone(&fixture.ledger);
    const copy = second; // Zig copies Ref values: the stale copy of a released Ref
    second.release(&fixture.ledger);
    var stale = copy;
    stale.release(&fixture.ledger);
    try testing.expectEqual(@as(u64, 1), fixture.ledger.violations);
    // The count is the creator's one, not underflowed or double-dropped.
    try testing.expectEqual(@as(u32, 1), refcount.count(first.get()));
    first.release(&fixture.ledger);
    try testing.expectEqual(@as(usize, 0), fixture.ledger.finish());
}

test "references outstanding at the end of the agent are leaks" {
    if (!refcount.tracking) return error.SkipZigTest;
    var fixture: Fixture = undefined;
    fixture.init(.log);
    defer fixture.deinit();
    var kept = try fixture.born();
    var released = try fixture.born();
    released.release(&fixture.ledger);
    _ = &kept;
    try testing.expectEqual(@as(usize, 1), fixture.ledger.outstanding());
    try testing.expectEqual(@as(usize, 1), fixture.ledger.finish());
    try testing.expectEqual(@as(u64, 1), fixture.ledger.violations);
}

test "leaks report their acquisition stack when tracing" {
    if (!refcount.tracking) return error.SkipZigTest;
    var fixture: Fixture = undefined;
    fixture.init(.log);
    fixture.ledger.options.trace = true;
    defer fixture.deinit();
    var kept = try fixture.born();
    _ = &kept;
    try testing.expectEqual(@as(usize, 1), fixture.ledger.outstanding());
    var it = fixture.ledger.entries.iterator();
    const entry = it.next().?.value_ptr.*;
    try testing.expect(entry.address_count > 0);
    try testing.expectEqual(@as(usize, 1), fixture.ledger.finish());
}

test "a ref on the root of a garbage tree, or on a node being destroyed, is a violation and takes nothing" {
    var fixture: Fixture = undefined;
    fixture.init(.log);
    defer fixture.deinit();
    var creator = try fixture.born();
    const node = creator.get();
    creator.release(&fixture.ledger);
    try testing.expect(node.rc_flags.garbage);
    refcount.ref(&fixture.ledger, node);
    try testing.expectEqual(@as(u64, 1), fixture.ledger.violations);
    try testing.expectEqual(@as(u32, 0), refcount.count(node));

    var other = try fixture.born();
    refcount.beginDestroy(other.get());
    refcount.ref(&fixture.ledger, other.get());
    try testing.expectEqual(@as(u64, 2), fixture.ledger.violations);
    try testing.expectEqual(@as(u32, 1), refcount.count(other.get()));
}

test "a garbage root that is held again fails its re-check; the flag is cleared" {
    var fixture: Fixture = undefined;
    fixture.init(.log);
    defer fixture.deinit();
    var creator = try fixture.born();
    const node = creator.get();
    creator.release(&fixture.ledger);
    try testing.expect(refcount.recheck(&fixture.ledger, node, false));
    // Something linked the root under a parent between the queueing and the slice.
    var parent_ref = try fixture.born();
    node.parent_node = parent_ref.get();
    try testing.expect(!refcount.recheck(&fixture.ledger, node, true));
    try testing.expect(!node.rc_flags.garbage);
    try testing.expectEqual(@as(u64, 1), fixture.ledger.resurrections);
    try testing.expectEqual(@as(u64, 0), fixture.ledger.violations);
    // Not on the allowlist: a violation in Debug.
    node.rc_flags.garbage = true;
    try testing.expect(!refcount.recheck(&fixture.ledger, node, false));
    try testing.expectEqual(@as(u64, if (refcount.tracking) 1 else 0), fixture.ledger.violations);
    node.parent_node = null;
}

test "the parent bit is independent of the count" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var creator = try fixture.born();
    const node = creator.get();
    refcount.setParentBit(node, true);
    try testing.expectEqual(@as(u32, 1), refcount.count(node));
    try testing.expect(refcount.hasParentBit(node));
    creator.release(&fixture.ledger);
    try testing.expect(refcount.hasParentBit(node));
    try testing.expectEqual(@as(u32, 0), refcount.count(node));
    refcount.setParentBit(node, false);
    try testing.expectEqual(@as(u32, 0), node.rc);
}

test "GCReachableRef: a counted set the engine reads, and a Ref" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    const Observer = struct {
        var changes: u32 = 0;
        var last: bool = false;
        fn changed(_: ?*anyopaque, _: *NodeBase, reachable: bool) void {
            changes += 1;
            last = reachable;
        }
    };
    Observer.changes = 0;
    fixture.ledger.options.gc_reachable_observer = .{ .changed = Observer.changed };
    var creator = try fixture.born();
    const node = creator.get();
    try testing.expect(!fixture.ledger.gcReachable(node));

    var first = try refcount.GCReachableRef(NodeBase).retain(&fixture.ledger, node);
    var second = try refcount.GCReachableRef(NodeBase).retain(&fixture.ledger, node);
    try testing.expect(fixture.ledger.gcReachable(node));
    try testing.expectEqual(@as(u32, 1), Observer.changes); // 0 to 1 once
    try testing.expect(Observer.last);
    try testing.expectEqual(@as(u32, 3), refcount.count(node));

    first.release(&fixture.ledger);
    try testing.expect(fixture.ledger.gcReachable(node));
    second.release(&fixture.ledger);
    try testing.expect(!fixture.ledger.gcReachable(node));
    try testing.expectEqual(@as(u32, 2), Observer.changes);
    try testing.expect(!Observer.last);
    try testing.expectEqual(@as(u32, 1), refcount.count(node));
    creator.release(&fixture.ledger);
    try testing.expectEqual(@as(usize, 0), fixture.ledger.finish());
}

var dummy_methods: u8 = 0;
const dummy_vtable: runtime.VTable = .{ .name = "RcTest", .deinit = null, .methods_ptr = &dummy_methods };

test "WeakRef: null once the node's slab slot is freed or reissued, and for a garbage tree" {
    var slab_value = runtime.SlabAllocator.init(testing.allocator);
    defer slab_value.deinit();
    const slab = &slab_value;

    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var creator = try fixture.born();
    const node = creator.get();

    // A NodeBase with no owning Instance has no generation to compare.
    try testing.expect(refcount.WeakRef(NodeBase).of(node) == null);

    const instance = try slab.alloc(&dummy_vtable);
    node.owner_instance = instance;
    const weak = refcount.WeakRef(NodeBase).of(node).?;
    try testing.expectEqual(node, weak.get(&fixture.ledger).?);

    // A garbage tree reads as gone before anything is freed.
    var holder = refcount.Ref(NodeBase).retain(&fixture.ledger, node);
    creator.release(&fixture.ledger);
    try testing.expectEqual(node, weak.get(&fixture.ledger).?);
    holder.release(&fixture.ledger);
    try testing.expect(node.rc_flags.garbage);
    try testing.expect(weak.get(&fixture.ledger) == null);

    // Freed and reissued: the address is the same, the generation is not.
    node.rc_flags.garbage = false;
    try testing.expectEqual(node, weak.get(&fixture.ledger).?);
    slab.free(instance);
    try testing.expect(weak.get(&fixture.ledger) == null);
    const reissued = try slab.alloc(&dummy_vtable);
    try testing.expect(weak.get(&fixture.ledger) == null);
    slab.free(reissued);
    node.owner_instance = null;
}

/// What every concrete node type is: NodeBase first, state after it.
const Concrete = struct { base: NodeBase, extra: u32 };

test "a Ref of a concrete node type counts through its NodeBase" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    const concrete = try testing.allocator.create(Concrete);
    defer testing.allocator.destroy(concrete);
    concrete.* = .{ .base = .{
        .allocator = testing.allocator,
        .node_type = NodeBase.ELEMENT_NODE,
        .node_name = "span",
        .child_nodes = .init(testing.allocator),
        .registered_observers = .init(testing.allocator),
    }, .extra = 7 };
    var born = refcount.Ref(Concrete).adopt(&fixture.ledger, concrete);
    var second = born.clone(&fixture.ledger);
    try testing.expectEqual(@as(u32, 2), refcount.count(&concrete.base));
    try testing.expectEqual(@as(u32, 7), second.get().extra);
    second.release(&fixture.ledger);
    born.release(&fixture.ledger);
    try testing.expectEqual(@as(u32, 0), concrete.base.subtree_holds);
    try testing.expect(concrete.base.rc_flags.garbage);
    try testing.expectEqual(@as(usize, 0), fixture.ledger.finish());
}

test "take hands a reference to code that holds it without a Ref" {
    var fixture: Fixture = undefined;
    fixture.init(.fatal);
    defer fixture.deinit();
    var born = try fixture.born();
    const node = born.take(&fixture.ledger);
    try testing.expectEqual(@as(usize, 0), fixture.ledger.outstanding());
    try testing.expectEqual(@as(u32, 1), refcount.count(node));
    refcount.deref(&fixture.ledger, node);
    try testing.expectEqual(@as(usize, 1), fixture.garbage.items.len);
}
