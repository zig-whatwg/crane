//! FetchLaterResult is initially inactive; activation storage is independent
//! of the native record that eventually sends the request.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn initialResult() !void {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const result = try interfaces.FetchLaterResult.init(allocator, &ctx);
    defer interfaces.FetchLaterResult.deinit(result);
    try std.testing.expect(!try interfaces.FetchLaterResult.get_activated(result));
}

test "FetchLaterResult is not activated when constructed" {
    const Run = struct {
        fn run(outcome: *?anyerror) void {
            initialResult() catch |err| {
                outcome.* = err;
            };
        }
    };
    var outcome: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&outcome});
    thread.join();
    if (outcome) |err| return err;
}
