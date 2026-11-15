//! Refcount step 5g (lane refcount4): an event's path holds its nodes only
//! while dispatch runs, by chainless counted references (node_holds
//! CountedRef: 16 B, no allocation, no chain link) - never by chained holds
//! in its items, which an event keeps after dispatch (the gc_bench
//! event-churn row: two node_holds holds per item made every uncollected
//! event's path 104 B an item larger, +79% peak RSS and +22% instructions).
//! Every way a dispatch ends lets them go: a throwing listener, a nested
//! dispatch, stopImmediatePropagation, a path node removed mid-dispatch, and
//! an allocation failure while the path is built.
//! Since lane ev1's second batch the path itself is the dispatch's
//! (dom.event_dispatch.DispatchPath, a local of EventTarget's dispatch), not
//! the event's: an uncollected event keeps no item at all.
//! SHADOW MODE: counts read through dom.refcount.count - the wrapper's (1;
//! it adopted the node's born reference, lane refcount7) + the holders'.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

test "a path item carries no chained hold, only chainless counted references" {
    try testing.expect(!@hasField(dom.event_dispatch.PathItem, "hold"));
    try testing.expect(!@hasField(dom.event_dispatch.PathItem, "related_hold"));
    try testing.expect(@FieldType(dom.event_dispatch.PathItem, "invocation_ref") == dom.node_holds.CountedRef);
    try testing.expect(@sizeOf(dom.node_holds.CountedRef) == 16);
    // Nor a list of its own: its touch targets are a run of the path's.
    try testing.expect(!@hasField(dom.event_dispatch.PathItem, "touch_target_list"));
    // And the event keeps no item: its path is the dispatch's.
    try testing.expect(@FieldType(dom.event_dispatch.EventState, "path") == ?*dom.event_dispatch.DispatchPath);
}

/// Reads its nodes' counts each time the page calls `probe()`.
const CountProbe = struct {
    nodes: []const *dom.NodeBase,
    seen: [8][4]u32 = std.mem.zeroes([8][4]u32),
    calls: usize = 0,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *CountProbe = @ptrCast(@alignCast(data.?));
        if (self.calls < self.seen.len) {
            for (self.nodes, 0..) |node, i| self.seen[self.calls][i] = dom.refcount.count(node);
        }
        self.calls += 1;
        return .undefined;
    }
};

const tree =
    \\globalThis.outer = document.createElement('div');
    \\globalThis.mid = outer.appendChild(document.createElement('p'));
    \\globalThis.leaf = mid.appendChild(document.createElement('span'));
    \\globalThis.other = document.createElement('b');
;

fn openTree(probe: *CountProbe, callback: *engine.BuiltinFunction) !struct { Page, [4]*dom.NodeBase } {
    const page = try Page.open();
    errdefer page.close();
    try page.run(tree);
    const nodes = [_]*dom.NodeBase{ try page.node("outer"), try page.node("mid"), try page.node("leaf"), try page.node("other") };
    callback.* = .{ .steps = CountProbe.steps, .data = probe };
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    try engine.defineBuiltinFunction(realm, "probe", 0, callback);
    return .{ page, nodes };
}

fn expectAllBack(nodes: []const *dom.NodeBase, what: []const u8) !void {
    for (nodes) |node| try expectCount(1, node, what);
}

fn exitsLetTheHoldsGo() !void {
    var probe: CountProbe = .{ .nodes = &.{} };
    var callback: engine.BuiltinFunction = undefined;
    const opened = try openTree(&probe, &callback);
    const page = opened[0];
    defer page.close();
    const nodes = opened[1];
    probe.nodes = &nodes;

    // A listener that throws: the exception is reported, dispatch goes on,
    // and its end lets the path go. The event is not kept (unseen after).
    try page.run(
        \\mid.addEventListener('a', () => { probe(); throw new Error('listener threw'); });
        \\window.onerror = () => true;
        \\leaf.dispatchEvent(new Event('a', { bubbles: true }));
    );
    try testing.expectEqual(@as(u32, 2), probe.seen[0][1]);
    try page.collect();
    try expectAllBack(&nodes, "after a throwing listener");

    // stopImmediatePropagation at the target: the path's remaining items
    // never run, and dispatch still ends through steps 7-11.
    try page.run(
        \\leaf.addEventListener('b', e => { probe(); e.stopImmediatePropagation(); });
        \\leaf.addEventListener('b', () => { throw new Error('ran after stopImmediatePropagation'); });
        \\outer.addEventListener('b', () => { throw new Error('bubbled after stopImmediatePropagation'); });
        \\leaf.dispatchEvent(new Event('b', { bubbles: true }));
    );
    try testing.expectEqual(@as(u32, 2), probe.seen[1][2]);
    try page.collect();
    try expectAllBack(&nodes, "after stopImmediatePropagation");

    // A nested dispatch from a listener, of another event at another node:
    // both paths hold their nodes at once, each lets its own go.
    try page.run(
        \\outer.addEventListener('c', () => { other.dispatchEvent(new Event('d')); });
        \\other.addEventListener('d', () => probe());
        \\leaf.dispatchEvent(new Event('c', { bubbles: true }));
    );
    // outer, mid and leaf held by the outer dispatch's path; other by the
    // nested one's (its target hold comes only when that dispatch ends).
    try testing.expectEqual([4]u32{ 2, 2, 2, 2 }, probe.seen[2]);
    try page.collect();
    try expectAllBack(&nodes, "after a nested dispatch");

    // Re-dispatching the same event from its own listener throws
    // InvalidStateError (dispatch step 1) and changes no hold.
    try page.run(
        \\outer.addEventListener('e', ev => { try { leaf.dispatchEvent(ev); throw new Error('no throw'); } catch (x) { if (x.name !== 'InvalidStateError') throw x; probe(); } });
        \\leaf.dispatchEvent(new Event('e', { bubbles: true }));
    );
    try testing.expectEqual(@as(u32, 2), probe.seen[3][2]);
    try page.collect();
    try expectAllBack(&nodes, "after a re-entrant dispatch was refused");

    // A path node removed mid-dispatch: the path still names it and holds
    // it until dispatch ends; then it is let go like the rest.
    try page.run(
        \\leaf.addEventListener('f', () => { mid.remove(); });
        \\outer.addEventListener('f', () => probe());
        \\leaf.dispatchEvent(new Event('f', { bubbles: true }));
    );
    try testing.expectEqual([4]u32{ 2, 2, 2, 1 }, probe.seen[4]);
    try page.collect();
    try expectAllBack(&nodes, "after a path node was removed mid-dispatch");
}

test "every way a dispatch ends lets the path's holds go" {
    try onFreshThread(exitsLetTheHoldsGo);
}

/// How many times `holdAndClear` puts each node on its path: enough that the
/// path outgrows a dispatch's inline items and takes storage from the
/// allocator, which can refuse.
const rounds = dom.event_dispatch.DispatchPath.inline_capacity / 3 + 2;

/// One build-and-release of a path over `nodes` with `allocator` serving
/// it, as dispatch does: the path is appended (where the allocator can
/// refuse), `hold` takes the references, `releaseHolds` lets them go.
fn holdAndClear(allocator: std.mem.Allocator, instances: []const *runtime.Instance, nodes: []const *dom.NodeBase, related: *runtime.Instance) !void {
    var path: dom.event_dispatch.DispatchPath = undefined;
    path.init(allocator);
    defer path.deinit();
    for (0..rounds) |_| {
        for (instances, nodes) |instance, node| {
            try path.append(.{
                .invocation_target = instance,
                .related_target = related,
                .target = instances[0],
                .invocation_node = node,
                .has_shadow_adjusted_target = false,
                .invocation_target_in_shadow_tree = false,
                .root_of_closed_tree = false,
                .slot_in_closed_tree = false,
            });
        }
    }
    try testing.expect(path.heap.len != 0);
    // The path is built (every append above succeeded): its references are
    // taken - no allocation - and `releaseHolds` lets them go.
    path.hold();
    for (nodes) |node| try expectCount(1 + rounds, node, "held by the path");
    path.releaseHolds();
    for (nodes) |node| try expectCount(1, node, "after the path let go");
}

fn allocationFailureLeavesNothing() !void {
    var probe: CountProbe = .{ .nodes = &.{} };
    var callback: engine.BuiltinFunction = undefined;
    const opened = try openTree(&probe, &callback);
    const page = opened[0];
    defer page.close();
    const nodes = opened[1];
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    var instances: [3]*runtime.Instance = undefined;
    for (&instances, [_][]const u8{ "outer", "mid", "leaf" }) |*slot, name| {
        const held = try page.browser.evaluateScript(name);
        defer held.release();
        slot.* = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
    }
    const other_held = try page.browser.evaluateScript("other");
    defer other_held.release();
    const other = engine.convertToPlatformObject(realm, other_held.borrow()) orelse return error.NotAPlatformObject;
    try testing.checkAllAllocationFailures(testing.allocator, holdAndClear, .{ &instances, nodes[0..3], other });
    try expectAllBack(&nodes, "after every allocation failure");
}

test "an allocation failure while the path is built leaves no count behind" {
    try onFreshThread(allocationFailureLeavesNothing);
}
