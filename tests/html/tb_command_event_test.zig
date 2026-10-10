const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const t = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(t.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(t.allocator, .{});
    defer context.deinit();
    const event = try interfaces.CommandEvent.call_constructor(&context, runtime.DOMString.initInterned("command"), .passed(.{ .base = .{ .bubbles = true, .cancelable = true }, .command = runtime.DOMString.initInterned("--custom") }));
    defer runtime.Instance.deinit(event);
    var event_type = try interfaces.Event.get_type(event);
    defer event_type.deinit(t.allocator);
    try t.expectEqualStrings("command", event_type.asSlice());
    var command = try interfaces.CommandEvent.get_command(event);
    defer command.deinit(t.allocator);
    try t.expectEqualStrings("--custom", command.asSlice());
    try t.expectEqual(null, try interfaces.CommandEvent.get_source(event));
    try t.expect(try interfaces.Event.get_bubbles(event));
    try t.expect(try interfaces.Event.get_cancelable(event));
    try interfaces.Event.call_preventDefault(event);
    try t.expect(try interfaces.Event.get_defaultPrevented(event));
}

test "CommandEvent initializes Event and owns command text" {
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
