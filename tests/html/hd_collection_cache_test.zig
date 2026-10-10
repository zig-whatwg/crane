//! The live-collection cache uses injected versions; no engine or global state.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const live = dom.live_collections;
const testing = std.testing;

const Walk = struct {
    root: *runtime.Instance,
    steps: usize = 0,

    pub fn first(self: *@This()) ?*runtime.Instance {
        self.steps += 1;
        return interfaces.Node.get_firstChild(self.root) catch null;
    }
    pub fn next(self: *@This(), node: *runtime.Instance) ?*runtime.Instance {
        self.steps += 1;
        return interfaces.Node.get_nextSibling(node) catch null;
    }
};

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            body() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

fn append(doc: *runtime.Instance, root: *runtime.Instance) !*runtime.Instance {
    const node = try interfaces.Document.call_createElementNS(doc, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("div"), .notPassed());
    errdefer dom.node_creation.destroyUninserted(node);
    _ = try interfaces.Node.call_appendChild(root, node);
    return node;
}

fn cacheInvalidation() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const other = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(other);
    const root = try append(doc, doc);
    const first = try append(doc, root);
    const second = try append(doc, root);
    const root_link = live.Link.to(root);
    var cache: live.IndexCache = .{};
    var walk = Walk{ .root = root };

    // The final integration must supply a real document version. Pure null
    // injection below still pins the safe always-recompute fallback.
    const production_version = live.treeVersion(doc);
    if (production_version == null) {
        std.debug.print("live tree-version seam remains null: TestUnexpectedResult\n", .{});
        return error.TestUnexpectedResult;
    }
    try testing.expect(!cache.begin(root_link, doc, null));
    try testing.expectEqual(@as(u32, 2), cache.count(&walk));
    const old_steps = walk.steps;
    try testing.expect(!cache.begin(root_link, doc, null));
    try testing.expectEqual(@as(u32, 2), cache.count(&walk));
    try testing.expect(walk.steps > old_steps);

    try testing.expect(!cache.begin(root_link, doc, 1));
    try testing.expectEqual(first, cache.item(&walk, 0).?);
    try testing.expect(cache.begin(root_link, doc, 1));
    try testing.expectEqual(second, cache.item(&walk, 1).?);
    try testing.expectEqual(@as(u32, 2), cache.count(&walk));
    const cached_steps = walk.steps;
    try testing.expect(cache.begin(root_link, doc, 1));
    try testing.expectEqual(@as(u32, 2), cache.count(&walk));
    try testing.expectEqual(cached_steps, walk.steps);
    try testing.expectEqual(null, cache.item(&walk, 2));
    try testing.expectEqual(first, cache.item(&walk, 0).?);

    _ = try interfaces.Node.call_removeChild(root, first);
    defer dom.node_creation.destroyUninserted(first);
    try testing.expect(!cache.begin(root_link, doc, 2));
    try testing.expectEqual(second, cache.item(&walk, 0).?);
    try testing.expectEqual(@as(u32, 1), cache.count(&walk));

    // Adopt the actual root. The adapter must ask for its CURRENT document;
    // the same numeric version in that other document cannot reuse state.
    _ = try interfaces.Document.call_adoptNode(other, root);
    _ = try interfaces.Node.call_appendChild(other, root);
    try testing.expectEqual(other, live.nodeDocument(root).?);
    try testing.expect(!cache.begin(root_link, live.nodeDocument(root), 2));
    _ = cache.item(&walk, 0);
    // A node freed outside mutation must invalidate the cursor's Link too.
    _ = try interfaces.Node.call_removeChild(root, second);
    dom.node_creation.destroyUninserted(second);
    try testing.expect(!cache.begin(root_link, other, 2));
    try testing.expectEqual(@as(u32, 0), cache.count(&walk));
    _ = try interfaces.Node.call_removeChild(other, root);
    dom.node_creation.destroyUninserted(root);
    try testing.expect(!cache.begin(root_link, other, 2));
}

fn linearWalk() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const root = try append(doc, doc);
    var totals: [2]usize = undefined;
    var populated: usize = 0;
    for ([_]usize{ 1_000, 10_000 }, 0..) |size, round| {
        while (populated < size) : (populated += 1) _ = try append(doc, root);
        var cache: live.IndexCache = .{};
        var walk = Walk{ .root = root };
        const link = live.Link.to(root);
        var index: u32 = 0;
        while (true) : (index += 1) {
            _ = cache.begin(link, doc, 1);
            if (index >= cache.count(&walk)) break;
            _ = cache.begin(link, doc, 1);
            try testing.expect(cache.item(&walk, index) != null);
        }
        try testing.expectEqual(size, index);
        // One pass for length and one for indexing; no full scan per index.
        try testing.expect(walk.steps <= size * 2 + 2);
        totals[round] = walk.steps;
    }
    try testing.expect(totals[1] <= totals[0] * 10 + 2);
    std.debug.print("collection cache: 1000 nodes {d} steps; 10000 nodes {d} steps\n", .{ totals[0], totals[1] });
}

test "live collection cache invalidates null, changed, adopted and dead links" {
    try onFreshThread(cacheInvalidation);
}

test "live collection length and ascending indexed reads take linear walks" {
    try onFreshThread(linearWalk);
}
