//! The ignored ping response cannot expose cancellation to script. Measure
//! its actual AsyncFetch lifetime before the network pump can settle it.
const std = @import("std");
const browser_mod = @import("browser");

test "window stop synchronously ends a started hyperlink audit transport" {
    const Run = struct {
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(_: *@This()) !void {
            const allocator = std.testing.allocator;
            var browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
            // The window agent's fetches and their scheduler.
            const fetches = &browser.agent_host.fetches;
            const scheduler = &fetches.scheduler;
            const before = fetches.inFlight();
            const transfers_before = scheduler.inFlight();
            try page.runScript(
                \\const link = document.createElement('a');
                \\link.href = '#followed';
                \\link.setAttribute('ping', 'http://127.0.0.1:65533/ping');
                \\link.click();
            );
            // The client has started its transport, even if the endpoint
            // refuses it when the network next pumps. Nothing is pumped here.
            try std.testing.expectEqual(before + 1, fetches.inFlight());
            try std.testing.expectEqual(transfers_before + 1, scheduler.inFlight());
            try page.runScript("window.stop()");
            try std.testing.expectEqual(before, fetches.inFlight());
            try std.testing.expectEqual(transfers_before, scheduler.inFlight());
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
