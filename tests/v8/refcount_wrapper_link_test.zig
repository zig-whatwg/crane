//! The wrapper link, V8 side (refcount design 2.1, section 7 step 4): a node's
//! wrapper owns one reference. The wrapper cache takes it in `set` (through
//! runtime.lifetime, which reaches dom.refcount) and lets it go exactly once:
//! in the second pass, at removal or replacement, at its realm's end - or when
//! the node's own teardown begins under a live wrapper (shadow mode: the
//! collector still frees, so a released node may be freed right after; a node
//! freed some other way is forgotten, never read).
//!
//! Wrappers are made the way the binding makes them (script, retainValue) and
//! collected by the engine.

const std = @import("std");
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

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
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
/// script holds: born with one reference each, none wrapped.
fn chain(page: Page) ![3]*runtime.Instance {
    const document = try page.instance("globalThis.d = new Document(); d");
    var nodes: [3]*runtime.Instance = undefined;
    for (&nodes) |*node| {
        node.* = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    }
    _ = try interfaces.Node.call_appendChild(nodes[0], nodes[1]);
    _ = try interfaces.Node.call_appendChild(nodes[1], nodes[2]);
    return nodes;
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

    fn begin() runtime.lifetime.Hooks {
        acquired = 0;
        released = 0;
        forgotten = 0;
        return runtime.lifetime.swapHooksForTest(.{ .acquire = acquire, .release = release, .forget = forget });
    }
};

test "a node's wrapper holds one reference, made with the wrapper" {
    const page = try Page.open();
    defer page.close();
    const nodes = try chain(page);
    for (nodes) |node| try testing.expectEqual(@as(u32, 1), dom.refcount.count(nodeBase(node)));

    // Wrapping the leaf wraps its ancestors (node tracing): each wrapper takes
    // its reference.
    const leaf = try protocol.retainValue(page.realm, .{ .instance = nodes[2] });
    defer leaf.release();
    for (nodes) |node| try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(node)));
    // A second read of the same wrapper takes nothing.
    const again = try protocol.retainValue(page.realm, .{ .instance = nodes[2] });
    again.release();
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[2])));
    // Holds did not move: every node was held already (its born reference).
    try testing.expectEqual(@as(u32, 3), nodeBase(nodes[0]).subtree_holds);
}

test "a node whose teardown begins under its live wrapper lets the wrapper's reference go once" {
    const saved = Tally.begin();
    defer _ = runtime.lifetime.swapHooksForTest(saved);
    const page = try Page.open();
    defer page.close();
    const nodes = try chain(page);
    // The chain's document is wrapped (script made it); its nodes are not.
    const before = Tally.acquired;
    // The middle node's wrapper, and its root's (node tracing).
    const middle = try protocol.retainValue(page.realm, .{ .instance = nodes[1] });
    try testing.expectEqual(before + 2, Tally.acquired);
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[1])));
    // What deinitNodeByType tells the engine as a node's teardown starts.
    protocol.platformObjectDestroyed(nodes[1]);
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(nodeBase(nodes[1])));
    try testing.expectEqual(@as(usize, 1), Tally.released);
    // The tree goes once script lets go: the root's wrapper lets its
    // reference go, and the middle node's finalization has nothing left to.
    middle.release();
    try page.collect();
    try testing.expectEqual(@as(usize, 2), Tally.released);
    try testing.expectEqual(@as(usize, 0), Tally.forgotten);
}

test "removing a wrapper from the cache lets its reference go" {
    const page = try Page.open();
    defer page.close();
    const nodes = try chain(page);
    const leaf = try protocol.retainValue(page.realm, .{ .instance = nodes[2] });
    leaf.release();
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(nodeBase(nodes[2])));
    try testing.expect(page.cache().remove(nodes[2]));
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(nodeBase(nodes[2])));
}

test "every reference a wrapper takes is let go: collections, the realm's end" {
    const saved = Tally.begin();
    defer _ = runtime.lifetime.swapHooksForTest(saved);
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
    // Each one released, or - shadow mode - forgotten with a node the
    // collector freed under its waiting wrapper.
    try testing.expectEqual(Tally.acquired, Tally.released + Tally.forgotten);
}
