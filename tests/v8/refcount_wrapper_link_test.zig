//! The wrapper link, V8 side (refcount design 2.1, section 7 step 4): a node's
//! wrapper owns one reference. The wrap takes it (through runtime.lifetime,
//! which reaches dom.refcount) and lets it go exactly once: at the drain after
//! the collection that took the wrapper, at its agent's end
//! (engine.releaseNodeWrappers) - or when the node's own teardown begins under
//! a live wrapper. Since the wrapper redesign's P2 a node's wrapper is in its
//! own slot, never in a wrapper cache, and its realm's end lets it go no more;
//! the counts decide every free, so a node the test keeps is let go by the
//! test (`releaseChain`).
//!
//! Wrappers are made the way the binding makes them (script, retainValue) and
//! collected by the engine.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

/// What every test here needs started: the engine, the process's hooks and
/// the standalone runtime (test_process.zig).
fn setup() !void {
    test_process.start();
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn eval(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    fn cache(self: Page) *v8.wrapper_cache_mod.WrapperCache {
        return @ptrCast(@alignCast(self.realm.getV8WrapperCacheStorage().?));
    }
};

const xhtml = "http://www.w3.org/1999/xhtml";

fn nodeBase(node: *runtime.Instance) *dom.NodeBase {
    return dom.instance_bridge.getNodeBase(node).?;
}

/// A detached root > middle > leaf chain of divs made natively in a Document
/// script holds: born with one reference each, which the test keeps (it
/// claims each, as a creator that keeps its nodes does - refcount7), none
/// wrapped. The test lets them go (`releaseChain`): the counts decide, and
/// nothing frees a tree its creator still holds.
fn chain(page: Page) ![3]*runtime.Instance {
    const document = try page.instance("globalThis.d = new Document(); d");
    var nodes: [3]*runtime.Instance = undefined;
    for (&nodes) |*node| {
        node.* = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
        _ = dom.refcount.claimCreatorReference(nodeBase(node.*));
    }
    _ = try interfaces.Node.call_appendChild(nodes[0], nodes[1]);
    _ = try interfaces.Node.call_appendChild(nodes[1], nodes[2]);
    return nodes;
}

/// The creator's references `chain` claimed, let go: the tree is its
/// wrappers' alone from here, and goes with them (the agent's end at the
/// latest, through its queue).
fn releaseChain(nodes: [3]*runtime.Instance) void {
    for (nodes) |node| dom.refcount.holderDeref(nodeBase(node));
}

/// runtime.lifetime's hooks, counted: dom.refcount's own, with a tally of
/// every reference taken and let go.
const Tally = struct {
    var acquired: usize = 0;
    var released: usize = 0;
    var forgotten: usize = 0;

    fn acquire(instance: *runtime.Instance) ?*anyopaque {
        const target = dom.refcount.wrapperAcquire(instance) orelse return null;
        acquired += 1;
        return target;
    }

    fn release(target: *anyopaque) void {
        released += 1;
        dom.refcount.wrapperRelease(target);
    }

    fn forget() void {
        forgotten += 1;
    }

    /// The process starts first, so the override covers dom.refcount's
    /// installed hooks and its restore brings them back (a start inside the
    /// override would install under it - hook.zig).
    fn begin() runtime.lifetime.HooksOverride {
        test_process.start();
        acquired = 0;
        released = 0;
        forgotten = 0;
        // The whole table is overridden: dom.refcount's slot hook goes in
        // with the tallied pair (the adapter reaches a node's wrapper slot
        // only through it, wrapper redesign P1).
        return runtime.lifetime.overrideHooksForTest(.{ .acquire = acquire, .release = release, .forget = forget, .slot_of = dom.refcount.wrapperSlotOf, .target_of_slot = dom.refcount.wrapperTargetOfSlot });
    }
};

test "a node's wrapper holds one reference, made with the wrapper" {
    const page = try Page.open();
    defer page.close();
    const nodes = try chain(page);
    defer releaseChain(nodes);
    for (nodes) |node| try testing.expectEqual(@as(u32, 1), dom.refcount.count(nodeBase(node)));

    // Wrapping the leaf takes the leaf's reference, and no ancestor's: since
    // the wrapper redesign's P7 a wrap wraps no ancestor (until P7 node
    // tracing's upward closure wrapped each, and each wrapper took one).
    const leaf = try protocol.retainValue(page.realm, .{ .instance = nodes[2] });
    defer leaf.release();
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[2])));
    for (nodes[0..2]) |node| try testing.expectEqual(@as(u32, 1), dom.refcount.count(nodeBase(node)));
    // A second read of the same wrapper takes nothing.
    const again = try protocol.retainValue(page.realm, .{ .instance = nodes[2] });
    again.release();
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[2])));
    // Holds did not move: every node was held already (its born reference).
    try testing.expectEqual(@as(u32, 3), nodeBase(nodes[0]).subtree_holds);
}

test "a node's first wrapper adopts the reference its creator offers, and takes none of its own" {
    const page = try Page.open();
    defer page.close();
    const document = try page.instance("globalThis.d = new Document(); d");
    const div = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    const node = nodeBase(div);
    // Born with one reference, offered (refcount7, H1).
    try testing.expect(node.rc_flags.creator);
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(node));
    const first = try protocol.retainValue(page.realm, .{ .instance = div });
    try testing.expect(!node.rc_flags.creator);
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(node));
    // A holder keeps the node while the first wrapper is collected: the
    // wrapper's (the adopted) reference goes with it.
    dom.refcount.holderRef(node);
    defer dom.refcount.holderDeref(node);
    first.release();
    try page.collect();
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(node));
    // A wrapper made again takes a reference of its own.
    const second = try protocol.retainValue(page.realm, .{ .instance = div });
    defer second.release();
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(node));
}

test "a node whose teardown begins under its live wrapper lets the wrapper's reference go once" {
    const override = Tally.begin();
    defer override.restore();
    const page = try Page.open();
    defer page.close();
    const nodes = try chain(page);
    defer releaseChain(nodes);
    // The chain's document is wrapped (script made it); its nodes are not.
    const before = Tally.acquired;
    // The middle node's wrapper alone (since the wrapper redesign's P7 its
    // root is not wrapped with it).
    const middle = try protocol.retainValue(page.realm, .{ .instance = nodes[1] });
    try testing.expectEqual(before + 1, Tally.acquired);
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[1])));
    // What deinitNodeByType tells the engine as a node's teardown starts.
    protocol.platformObjectDestroyed(nodes[1]);
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(nodeBase(nodes[1])));
    try testing.expectEqual(@as(usize, 1), Tally.released);
    // Once script lets go, the middle node's finalization has nothing left
    // to let go.
    middle.release();
    try page.collect();
    try testing.expectEqual(@as(usize, 1), Tally.released);
    try testing.expectEqual(@as(usize, 0), Tally.forgotten);
}

test "a node's wrapper is in no wrapper cache: there is no entry to remove, and the reference stays the wrapper's" {
    const page = try Page.open();
    defer page.close();
    const nodes = try chain(page);
    defer releaseChain(nodes);
    const leaf = try protocol.retainValue(page.realm, .{ .instance = nodes[2] });
    leaf.release();
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[2])));
    // The wrapper redesign's P2: a node's wrapper lives in its own slot, its
    // agent's - the realm's cache has no entry for it.
    try testing.expect(!page.cache().remove(nodes[2]));
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[2])));
    try testing.expect(protocol.hasWrapper(nodes[2]));
}

test "every reference a wrapper takes is let go: collections, the realm's end" {
    const override = Tally.begin();
    defer override.restore();
    {
        const page = try Page.open();
        defer page.close();
        try page.eval(
            \\globalThis.kept = [];
            \\const doc = new Document();
            \\doc.appendChild(doc.createElement('html'));
            \\globalThis.doc = doc;
            \\for (let i = 0; i < 200; i++) {
            \\  const root = doc.createElement('section');
            \\  root.innerHTML = '<p><b>x</b><i>y</i></p><span></span>';
            \\  const leaf = root.querySelector('i');
            \\  if (i % 4 == 0) kept.push(leaf);
            \\  if (i % 5 == 0) doc.documentElement.appendChild(root);
            \\}
            \\'ok'
        );
        try page.collect();
        try testing.expect(Tally.acquired > 0);
        try testing.expect(Tally.released > 0);
        try testing.expect(Tally.released < Tally.acquired);
    }
    // Each one released - at a collection's drain or at the agent's end - or
    // forgotten with a node a forced teardown freed under its waiting
    // release.
    try testing.expectEqual(Tally.acquired, Tally.released + Tally.forgotten);
}
