const std = @import("std");
const cases = @import("html").worker_host.worker_origin_oom_test_cases;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Thread = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Thread.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "pm2 worker startup owns its top-level origin across every allocation failure" {
    try onThread(cases.startup);
}

test "pm2 hosted worker scope unwinds its own state when a settings copy fails" {
    try onThread(cases.scopeCopies);
}
