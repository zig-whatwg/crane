//! HTML Media Capture reflection through the generated interface, with leak checks.
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

fn captureReflection() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const input = try interfaces.HTMLInputElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLInputElement.deinit(input);
    var absent = try interfaces.HTMLInputElement.get_capture(input);
    defer absent.deinit(testing.allocator);
    try testing.expectEqualStrings("", absent.asSlice());
    for ([_][]const u8{ "user", "environment", "USER", "unknown", "", " user " }) |value| {
        try interfaces.HTMLInputElement.set_capture(input, runtime.DOMString.initInterned(value));
        var actual = try interfaces.HTMLInputElement.get_capture(input);
        defer actual.deinit(testing.allocator);
        try testing.expectEqualStrings(value, actual.asSlice());
        var attribute = (try interfaces.Element.call_getAttributeNS(input, null, runtime.DOMString.initInterned("capture"))).?;
        defer attribute.deinit(testing.allocator);
        try testing.expectEqualStrings(value, attribute.asSlice());
    }
    try interfaces.Element.call_removeAttribute(input, runtime.DOMString.initInterned("capture"));
    var removed = try interfaces.HTMLInputElement.get_capture(input);
    defer removed.deinit(testing.allocator);
    try testing.expectEqualStrings("", removed.asSlice());
}

test "capture reflects raw content strings and absence" {
    try onFreshThread(captureReflection);
}
