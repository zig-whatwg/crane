//! HTML document accessors, through their real interfaces, with allocator checks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
const html_ns = "http://www.w3.org/1999/xhtml";

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

fn element(doc: *runtime.Instance, ns: ?[]const u8, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(doc, if (ns) |value| runtime.DOMString.initInterned(value) else null, runtime.DOMString.initInterned(name), .notPassed());
}

fn collectionLiveness() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const root = try element(doc, html_ns, "html");
    _ = try interfaces.Node.call_appendChild(doc, root);
    const images = try interfaces.Document.get_images(doc);
    defer runtime.Instance.deinit(images);
    try testing.expectEqual(@as(u32, 0), try interfaces.HTMLCollection.get_length(images));
    const img = try element(doc, html_ns, "img");
    _ = try interfaces.Node.call_appendChild(root, img);
    try testing.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(images));
    const foreign = try element(doc, "urn:foreign", "img");
    _ = try interfaces.Node.call_appendChild(root, foreign);
    const upper = try element(doc, html_ns, "IMG");
    _ = try interfaces.Node.call_appendChild(root, upper);
    try testing.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(images));
    try testing.expectEqual(img, (try interfaces.HTMLCollection.call_item(images, 0)).?);
    _ = try interfaces.Node.call_removeChild(root, img);
    defer dom.node_creation.destroyUninserted(img);
    try testing.expectEqual(@as(u32, 0), try interfaces.HTMLCollection.get_length(images));
}

test "document images follows mutations and HTML namespace filtering" {
    try onFreshThread(collectionLiveness);
}
