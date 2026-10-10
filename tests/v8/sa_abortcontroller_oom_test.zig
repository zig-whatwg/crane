//! An AbortController publishes its state only after its signal exists.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

const Trial = struct {
    fail_after: ?usize,
    allocations: usize = 0,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn check(self: *Trial) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        defer runtime.deinitializeRuntime();
        var failing = testing.FailingAllocator.init(testing.allocator, .{});
        var context = try runtime.ContextData.init(failing.allocator(), .{});
        defer context.deinit();
        const initial = failing.alloc_index;
        if (self.fail_after) |after| failing.fail_index = initial + after;
        const controller = interfaces.AbortController.call_constructor(&context) catch |err| {
            failing.fail_index = std.math.maxInt(usize);
            try testing.expect(self.fail_after != null);
            try testing.expectEqual(error.OutOfMemory, err);
            try testing.expect(failing.has_induced_failure);
            return;
        };
        self.allocations = failing.alloc_index - initial;
        failing.fail_index = std.math.maxInt(usize);
        defer runtime.Instance.deinit(controller);
        try testing.expect(self.fail_after == null);
        const signal = try interfaces.AbortController.get_signal(controller);
        try testing.expect(!try interfaces.AbortSignal.get_aborted(signal));
    }
};

test "AbortController construction cleans up every failed allocation" {
    var success: Trial = .{ .fail_after = null };
    const warm = try std.Thread.spawn(.{}, Trial.run, .{&success});
    warm.join();
    try success.result;
    try testing.expect(success.allocations > 0);
    for (0..success.allocations) |index| {
        var trial: Trial = .{ .fail_after = index };
        const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
        thread.join();
        trial.result catch |err| {
            std.debug.print("AbortController allocation failure index {d}/{d}\n", .{ index, success.allocations });
            return err;
        };
    }
}
