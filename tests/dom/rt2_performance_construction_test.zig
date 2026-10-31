//! Performance's generated construction chain includes EventTarget.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const EventHandler = @typeInfo(@TypeOf(interfaces.Performance.set_onresourcetimingbufferfull)).@"fn".param_types[1].?;

test "Performance initializes the EventTarget state used by event handlers" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            check() catch |err| {
                result.* = err;
            };
        }

        fn check() !void {
            const allocator = std.testing.allocator;
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            var ctx = try runtime.ContextData.init(allocator, .{});
            defer ctx.deinit();
            const performance = try interfaces.Performance.init(allocator, &ctx);
            defer runtime.Instance.deinit(performance);

            // Null deactivation still needs EventTarget's registered state.
            // This catches a legacy constructor even if an IDL stub masks it.
            try dom.event_handlers.setValue(EventHandler, performance, "onresourcetimingbufferfull", null);
            try interfaces.Performance.set_onresourcetimingbufferfull(performance, null);
            try std.testing.expectEqual(@as(EventHandler, null), try interfaces.Performance.get_onresourcetimingbufferfull(performance));
            try std.testing.expect((try interfaces.Performance.call_now(performance)) >= 0);
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
