//! Location ancestor origins with no browsing context.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

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

test "Location without a relevant document exposes a stable empty ancestor list" {
    try onFreshThread(struct {
        fn run() !void {
            const allocator = std.testing.allocator;
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            var ctx = try runtime.ContextData.init(allocator, .{});
            defer ctx.deinit();
            const location = try interfaces.Location.init(allocator, &ctx);
            defer runtime.Instance.deinit(location);
            const list = try interfaces.Location.get_ancestorOrigins(location);
            defer runtime.Instance.deinit(list);
            try std.testing.expectEqual(@as(u32, 0), try interfaces.DOMStringList.get_length(list));
            try std.testing.expectEqual(list, try interfaces.Location.get_ancestorOrigins(location));
        }
    }.run);
}
