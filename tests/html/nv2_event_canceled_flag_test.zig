//! HTML's abort-navigation steps directly set the canceled flag, including
//! a noncancelable traversal event. Script's preventDefault remains guarded.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(std.testing.allocator, .{});
    defer ctx.deinit();
    const event = try interfaces.Event.call_constructor(&ctx, runtime.DOMString.initInterned("navigate"), .passed(.{ .cancelable = false }));
    defer runtime.Instance.deinit(event);
    try interfaces.Event.call_preventDefault(event);
    try std.testing.expect(!try interfaces.Event.get_defaultPrevented(event));
    try std.testing.expect(try interfaces.Event.get_returnValue(event));
    dom.event_construction.forceCanceledFlag(event);
    try std.testing.expect(try interfaces.Event.get_defaultPrevented(event));
    try std.testing.expect(!try interfaces.Event.get_returnValue(event));
    try std.testing.expect(!try interfaces.Event.get_cancelable(event));
}

test "navigation can cancel a noncancelable event without changing preventDefault" {
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
