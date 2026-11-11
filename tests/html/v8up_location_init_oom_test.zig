//! A Location that could not be made frees what it allocated: HTML "create a
//! new realm" makes a Window's Location with the Window ("the Window
//! object's associated Location object", 7.2.2.1), and Crane makes it when
//! a navigation's new realm gets its Window (attachRealm ->
//! giveLocationNavigateCallback -> Window.get_location). LocationImpl.init
//! had no errdefer: an out-of-memory failure of its URL parse left its
//! internal state and its URL record allocated for good - 10 of the 24
//! blocks tests/html/iframe_policy_container_oom_test.zig's contentWindow
//! sweep found live after Browser.deinit (lane v8up b3h, chat2).
//!
//! Each case fails the i-th allocation of `interfaces.Location.init`, for
//! i = 0, 1, 2, ... until one succeeds, and checks that the failed init
//! left nothing allocated.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn locationInitFreesWhatItAllocatedOnFailure() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;

    var failed: usize = 0;
    var index: usize = 0;
    while (index < 64) : (index += 1) {
        var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = index });
        const made = interfaces.Location.init(failing.allocator(), realm) catch |err| {
            try testing.expectEqual(error.OutOfMemory, err);
            failed += 1;
            if (failing.allocated_bytes != failing.freed_bytes or failing.allocations != failing.deallocations) {
                std.debug.print("failing allocation {d} of Location.init left {d} blocks ({d} bytes) allocated\n", .{ index, failing.allocations - failing.deallocations, failing.allocated_bytes - failing.freed_bytes });
                return error.LocationInitLeaked;
            }
            continue;
        };
        // Memory to spare: a Location, which nothing wrapped - its maker frees it.
        runtime.Instance.deinit(made);
        try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        break;
    }
    // The internal state, the URL record, and the URL parse's own
    // allocations: at least three ways to fail.
    if (failed < 3) {
        std.debug.print("Location.init failed only {d} ways before it succeeded\n", .{failed});
        return error.TooFewFailurePoints;
    }
}

test "a Location whose init runs out of memory - its URL parse included - frees what it allocated" {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            locationInitFreesWhatItAllocatedOnFailure() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
