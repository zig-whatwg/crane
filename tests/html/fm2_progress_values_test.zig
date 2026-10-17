//! HTML 4.10.13: progress getters derive values from the content attributes.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn attribute(element: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const progress = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("progress"), .notPassed());
    defer dom.node_creation.destroyUninserted(progress);

    try testing.expectEqual(@as(f64, 0), try interfaces.HTMLProgressElement.get_value(progress));
    try testing.expectEqual(@as(f64, -1), try interfaces.HTMLProgressElement.get_position(progress));
    try attribute(progress, "value", "2");
    try testing.expectEqual(@as(f64, 1), try interfaces.HTMLProgressElement.get_value(progress));
    try attribute(progress, "max", "4");
    try testing.expectEqual(@as(f64, 2), try interfaces.HTMLProgressElement.get_value(progress));
    try testing.expectEqual(@as(f64, 0.5), try interfaces.HTMLProgressElement.get_position(progress));
    try attribute(progress, "value", "  +3tail");
    try testing.expectEqual(@as(f64, 0.75), try interfaces.HTMLProgressElement.get_position(progress));
    for ([_][]const u8{ "", "garbage", "NaN", "Infinity", "1e999", "-4" }) |invalid| {
        try attribute(progress, "value", invalid);
        try testing.expectEqual(@as(f64, 0), try interfaces.HTMLProgressElement.get_value(progress));
        try testing.expectEqual(@as(f64, 0), try interfaces.HTMLProgressElement.get_position(progress));
    }
    try attribute(progress, "value", "0.5");
    for ([_][]const u8{ "", "0", "-1", "invalid", "Infinity" }) |invalid| {
        try attribute(progress, "max", invalid);
        try testing.expectEqual(@as(f64, 0.5), try interfaces.HTMLProgressElement.get_position(progress));
    }
    try interfaces.Element.call_removeAttribute(progress, runtime.DOMString.initInterned("value"));
    try testing.expectEqual(@as(f64, -1), try interfaces.HTMLProgressElement.get_position(progress));
}

test "progress getters preserve indeterminate state and parse clamp and normalize values" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
