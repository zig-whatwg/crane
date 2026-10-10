//! HTML document accessors, through their real interfaces, with allocator checks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
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

fn nameListLiveness() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const root = try element(doc, html_ns, "html");
    _ = try interfaces.Node.call_appendChild(doc, root);
    const list = try interfaces.Document.call_getElementsByName(doc, runtime.DOMString.initInterned("target"));
    defer runtime.Instance.deinit(list);
    try testing.expect(list.stateAs(interfaces.NodeList.State) != null);
    const child = try element(doc, html_ns, "div");
    _ = try interfaces.Node.call_appendChild(root, child);
    try interfaces.Element.call_setAttribute(child, runtime.DOMString.initInterned("name"), .{ .domstring = runtime.DOMString.initInterned("target") });
    try testing.expectEqual(@as(u32, 1), try interfaces.NodeList.get_length(list));
    try testing.expectEqual(child, (try interfaces.NodeList.call_item(list, 0)).?);
    try interfaces.Element.call_removeAttribute(child, runtime.DOMString.initInterned("name"));
    try testing.expectEqual(@as(u32, 0), try interfaces.NodeList.get_length(list));
}

test "getElementsByName returns a live NodeList with an owned filter" {
    try onFreshThread(nameListLiveness);
}
