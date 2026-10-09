//! Native liveness and stale-root safety for select-owned collections.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const select = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("select"), .notPassed());
    var select_live = true;
    defer if (select_live) dom.node_creation.destroyUninserted(select);
    const options = try interfaces.HTMLOptionsCollection.init(testing.allocator, &context);
    defer runtime.Instance.deinit(options);
    try dom.live_collections.selectOptions(options, select, false);
    try testing.expectEqual(select, dom.live_collections.rootOf(options).?);
    const option = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("option"), .notPassed());
    _ = try interfaces.Node.call_appendChild(select, option);
    try testing.expectEqual(@as(u32, 1), try interfaces.HTMLOptionsCollection.get_length(options));
    try testing.expectEqual(option, (try interfaces.HTMLCollection.call_item(options, 0)).?);
    dom.node_creation.destroyUninserted(select);
    select_live = false;
    try testing.expectEqual(null, dom.live_collections.rootOf(options));
    try testing.expectEqual(@as(u32, 0), try interfaces.HTMLOptionsCollection.get_length(options));
    try interfaces.HTMLOptionsCollection.set_length(options, 3);
    try testing.expectEqual(@as(u32, 0), try interfaces.HTMLOptionsCollection.get_length(options));
}

test "options collection is live and rejects a retired root before reading it" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
