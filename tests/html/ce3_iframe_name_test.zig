//! Iframe name reflection through the generated interface, with leak checks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

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

fn iframeNameReflection() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const frame = try interfaces.HTMLIFrameElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLIFrameElement.deinit(frame);
    const name = runtime.DOMString.initInterned("name");
    var absent = try interfaces.HTMLIFrameElement.get_name(frame);
    defer absent.deinit(testing.allocator);
    try testing.expectEqualStrings("", absent.asSlice());
    try interfaces.Element.call_setAttribute(frame, name, .{ .domstring = runtime.DOMString.initInterned("attribute") });
    var from_attribute = try interfaces.HTMLIFrameElement.get_name(frame);
    defer from_attribute.deinit(testing.allocator);
    try testing.expectEqualStrings("attribute", from_attribute.asSlice());
    for ([_][]const u8{ "", "first", "UPPER", " spaced ", "a\x00b" }) |value| {
        try interfaces.HTMLIFrameElement.set_name(frame, runtime.DOMString.initInterned(value));
        var actual = try interfaces.HTMLIFrameElement.get_name(frame);
        defer actual.deinit(testing.allocator);
        try testing.expectEqualStrings(value, actual.asSlice());
        var attribute = (try interfaces.Element.call_getAttributeNS(frame, null, name)).?;
        defer attribute.deinit(testing.allocator);
        try testing.expectEqualStrings(value, attribute.asSlice());
    }
    try interfaces.Element.call_removeAttribute(frame, name);
    try interfaces.Element.call_setAttributeNS(frame, runtime.DOMString.initInterned("urn:ce3"), runtime.DOMString.initInterned("x:name"), .{ .domstring = runtime.DOMString.initInterned("namespaced") });
    var removed = try interfaces.HTMLIFrameElement.get_name(frame);
    defer removed.deinit(testing.allocator);
    try testing.expectEqualStrings("", removed.asSlice());
}

test "iframe name reflects content attributes, raw strings and removal" {
    try onFreshThread(iframeNameReflection);
}
