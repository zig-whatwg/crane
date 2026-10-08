//! Async XHR accepts a host timer even without a script engine. The native
//! owner remains alive when the fetch's callable-realm check rejects it.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const async_fetch = @import("fetch").algorithms.async_fetch;
const scheduler = @import("fetch").network.scheduler;

test "engine-less asynchronous XHR clears native pending link when swept" {
    const Run = struct {
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(_: *@This()) !void {
            const allocator = std.testing.allocator;
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            defer scheduler.endIdleThreadScheduler();
            const timers = try runtime.native_timer.NativeTimerManager.init(allocator);
            defer timers.deinit();
            var context = try runtime.ContextData.init(allocator, .{ .timer = timers.timerInterface() });
            defer context.deinit();
            const request = try interfaces.XMLHttpRequest.call_constructor(&context);
            defer interfaces.XMLHttpRequest.deinit(request);
            const before = async_fetch.inFlight();
            try interfaces.XMLHttpRequest.call_open(request, "GET", "http://127.0.0.1:65533/pending");
            try interfaces.XMLHttpRequest.call_send(request, .{ .was_passed = false, .value = undefined });
            try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            try std.testing.expect(async_fetch.sweep());
            try std.testing.expectEqual(before, async_fetch.inFlight());
            // A still-live native XHR can be opened again after its fetch
            // is swept. This follows a freed PendingFetch on the old code;
            // exercise the public operation and ordinary owner teardown.
            try interfaces.XMLHttpRequest.call_open(request, "GET", "http://127.0.0.1:65533/replacement");
            try std.testing.expectEqual(@as(u16, 1), try interfaces.XMLHttpRequest.get_readyState(request));
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
