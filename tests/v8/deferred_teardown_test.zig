//! A collected node's teardown is deferred to its agent's queue
//! (engine.AgentOptions.deferred_teardown; runtime.gc.DeferredTeardown):
//! the collection that takes a detached tree's root wrapper only queues the
//! root, and the tree is freed a slice at a time - never in the second pass
//! that happened to run inside script - and fully at the realm's end, after a
//! requested collection, and at the agent's end, which closes the queue.
//!
//! The collections here are V8's own (LowMemoryNotification through the FFI),
//! not engine.requestGarbageCollection, which drains the queue by contract.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent per test.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const DeferredTeardown = runtime.gc.DeferredTeardown;
const SlabAllocator = runtime.SlabAllocator;

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
    SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,
    realm_open: bool = true,

    fn open(queue: *DeferredTeardown) !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .host = null,
            .deferred_teardown = queue,
        });
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

    fn endRealm(self: *Page) void {
        if (!self.realm_open) return;
        protocol.destroyWindowRealm(self.realm, .global_detached);
        self.realm_open = false;
    }

    fn close(self: *Page) void {
        self.endRealm();
        protocol.destroyAgent(self.agent);
    }

    fn run(self: Page, source: []const u8) !void {
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

    /// V8's own full collection, twice: the second pass runs synchronously
    /// for a forced one, and queues what it finds; nothing drains.
    fn collect(self: Page) void {
        const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(self.agent));
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
    }
};

/// A slab slot and the generation it had: whether the object is still there.
const Watched = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Watched {
        return .{ .instance = instance, .generation = SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Watched) bool {
        return SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// A detached <div> with `spans` <span>x</span> children made by innerHTML -
/// no node below the root has a wrapper - held by `globalThis.r` until
/// `drop`. 1 + 2 * spans nodes. Its Document is kept (`globalThis.doc`), so
/// the root is the only node a collection finds.
const Tree = struct {
    root: Watched,
    first_span: Watched,
    first_text: Watched,
    last_span: Watched,

    fn make(page: Page, spans: usize) !Tree {
        var source_buf: [256]u8 = undefined;
        const source = try std.fmt.bufPrint(&source_buf, "globalThis.doc ??= new Document(); globalThis.r = doc.createElement('div'); r.innerHTML = '<span>x</span>'.repeat({d}); r", .{spans});
        const root = try page.instance(source);
        const node = dom.instance_bridge.getNodeBase(@ptrCast(root)).?;
        const first = node.first_child.?;
        const last = node.last_child.?;
        return .{
            .root = Watched.of(root),
            .first_span = Watched.of(@ptrCast(@alignCast(first.owner_instance.?))),
            .first_text = Watched.of(@ptrCast(@alignCast(first.first_child.?.owner_instance.?))),
            .last_span = Watched.of(@ptrCast(@alignCast(last.owner_instance.?))),
        };
    }

    fn drop(page: Page) !void {
        try page.run("globalThis.r = null;");
    }

    fn childCount(self: Tree) usize {
        return dom.instance_bridge.getNodeBase(@ptrCast(self.root.instance)).?.child_nodes.size();
    }
};

test "the collection that takes a detached root's wrapper queues the root and frees nothing" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const tree = try Tree.make(page, 2000);
    try Tree.drop(page);
    page.collect();

    try testing.expectEqual(@as(usize, 1), queue.len());
    try testing.expectEqual(@as(usize, 4001), queue.pendingNodes());
    try testing.expect(tree.root.alive());
    try testing.expect(tree.first_text.alive());
    try testing.expectEqual(@as(usize, 2000), tree.childCount());
}

test "a queued tree is freed over several slices, leaves first, its root last" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const tree = try Tree.make(page, 2000);
    try Tree.drop(page);
    page.collect();

    var slices: usize = 0;
    while (!queue.isEmpty()) : (slices += 1) {
        const freed = queue.runSlice(DeferredTeardown.slice_budget);
        try testing.expect(freed <= DeferredTeardown.slice_budget);
        if (!queue.isEmpty()) try testing.expect(tree.root.alive());
        try testing.expect(slices < 100);
    }
    // 4,001 nodes, 512 a slice.
    try testing.expectEqual(@as(usize, 8), slices);
    try testing.expect(!tree.root.alive());
    try testing.expect(!tree.first_span.alive());
    try testing.expect(!tree.first_text.alive());
    try testing.expect(!tree.last_span.alive());
    try testing.expectEqual(@as(usize, 4001), queue.freed_total);
}

test "a queued root wrapped again before its slice is not torn down" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const tree = try Tree.make(page, 100);
    try Tree.drop(page);
    page.collect();
    try testing.expectEqual(@as(usize, 1), queue.len());

    // Something the host holds hands the root to script again: a new wrapper.
    const held = try protocol.createSequenceOfPlatformObjects(page.realm, &.{tree.root.instance});
    _ = queue.runSlice(DeferredTeardown.slice_budget);
    try testing.expect(queue.isEmpty());
    try testing.expect(tree.root.alive());
    try testing.expect(tree.first_text.alive());
    try testing.expectEqual(@as(usize, 100), tree.childCount());

    // Its new wrapper is collected in turn: queued again, and freed.
    held.release();
    page.collect();
    try testing.expectEqual(@as(usize, 1), queue.len());
    queue.drainAll();
    try testing.expect(!tree.root.alive());
    try testing.expect(!tree.first_text.alive());
}

test "a root wrapped again in the middle of its teardown keeps a whole, smaller tree" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const tree = try Tree.make(page, 1000);
    try Tree.drop(page);
    page.collect();

    // One slice: 512 nodes - the last 256 spans and their texts - gone.
    _ = queue.runSlice(DeferredTeardown.slice_budget);
    try testing.expect(!tree.last_span.alive());
    try testing.expectEqual(@as(usize, 744), tree.childCount());

    // Wrapped again: the queue lets go, and script sees the rest intact.
    const held = try protocol.createSequenceOfPlatformObjects(page.realm, &.{tree.root.instance});
    defer held.release();
    var reports: Reports = .{};
    const global = try protocol.evaluateClassicScript(page.realm, .{ .utf8 = "globalThis" }, "", null, reports.reporter());
    defer global.release();
    try protocol.setProperty(page.realm, global.value, "kept", held.value);
    _ = queue.runSlice(DeferredTeardown.slice_budget);
    try testing.expect(queue.isEmpty());
    try testing.expect(tree.root.alive());
    try page.run(
        \\const root = kept[0];
        \\if (root.childNodes.length !== 744) throw new Error('children: ' + root.childNodes.length);
        \\for (const span of root.childNodes) if (span.textContent !== 'x' || span.parentNode !== root) throw new Error('a span lost its text');
        \\if (root.lastChild.nextSibling !== null) throw new Error('a dangling sibling');
        \\globalThis.kept = null;
    );
}

test "the realm's end tears down what its collected roots queued" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const tree = try Tree.make(page, 1000);
    try Tree.drop(page);
    page.collect();
    try testing.expectEqual(@as(usize, 1), queue.len());

    page.endRealm();
    try testing.expect(queue.isEmpty());
    try testing.expect(!tree.root.alive());
    try testing.expect(!tree.first_text.alive());
}

test "a requested collection frees what it queued before it returns" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const tree = try Tree.make(page, 1000);
    try Tree.drop(page);
    protocol.requestGarbageCollection(page.agent);
    protocol.requestGarbageCollection(page.agent);
    try testing.expect(queue.isEmpty());
    try testing.expect(!tree.root.alive());
    try testing.expect(!tree.first_text.alive());
}

test "a Document root goes in one slice, whatever the budget" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const document = try page.instance(
        \\globalThis.d = new Document();
        \\d.appendChild(d.createElement('html')).innerHTML = '<span>x</span>'.repeat(50);
        \\d
    );
    const watched = Watched.of(document);
    const html = Watched.of(@ptrCast(@alignCast(dom.instance_bridge.getNodeBase(@ptrCast(document)).?.first_child.?.owner_instance.?)));
    try page.run("globalThis.d = null;");
    page.collect();
    try testing.expectEqual(@as(usize, 1), queue.len());
    _ = queue.runSlice(1);
    try testing.expect(queue.isEmpty());
    try testing.expect(!watched.alive());
    try testing.expect(!html.alive());
}

test "an object that is not a node is torn down by the second pass, as before" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();

    const headers = Watched.of(try page.instance("globalThis.h = new Headers(); h"));
    try page.run("globalThis.h = null;");
    page.collect();
    try testing.expect(queue.isEmpty());
    try testing.expect(!headers.alive());
}

test "the agent's end leaves its queue empty and closed: later collections tear down inline" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);

    const tree = try Tree.make(page, 10);
    try Tree.drop(page);
    page.collect();
    page.close();
    try testing.expect(queue.isEmpty());
    try testing.expect(queue.closed);
    try testing.expect(!tree.root.alive());
}
