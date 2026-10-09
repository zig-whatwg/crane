//! Shared by the edges_*_test.zig files: a page whose script can collect
//! (TestUtils.gc() runs teardown synchronously) and reissue freed slots with
//! nodes of the same type (`collectNow()`), on a thread of its own.
const std = @import("std");
const browser_mod = @import("browser");

pub fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

pub const Page = struct {
    browser: *browser_mod.Browser,

    pub fn open() !Page {
        const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        try page.runScript(
            \\globalThis.collectNow = () => {
            \\  TestUtils.gc();
            \\  const churn = [];
            \\  for (let i = 0; i < 1000; i++) churn.push(document.createTextNode('churn'), document.createElement('i'), document.createElement('span'));
            \\  TestUtils.gc();
            \\  return churn.length;
            \\};
        );
        return .{ .browser = browser };
    }

    pub fn close(self: Page) void {
        self.browser.deinit();
    }

    /// Run `source`; a thrown error fails the test.
    pub fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    /// The completion of `source` as a string, OWNED by std.testing.allocator.
    pub fn evaluate(self: Page, source: []const u8) ![]u8 {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.evaluateScriptToString(source, std.testing.allocator);
    }

    /// Leave the job that made a WeakRef, so its target can be collected.
    pub fn turn(self: Page) !void {
        _ = try self.browser.runEventLoopBlocking(20);
    }
};
