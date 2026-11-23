//! The console's remote debugging starts with ONE page, as headless Chrome
//! does: the browser's first page is its first window, navigated to the
//! command line's URL - never a second tab opened beside it (lane mcp1's
//! differential pass found `repl --mcp` listing two blank pages where Chrome
//! lists one; serveDevtools had the same shape, main 2:44 PM ET).
//! --no-startup-window keeps Chrome's "no window" start untouched.

const std = @import("std");
const testing = std.testing;
const repl = @import("repl");
const browser = @import("browser");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

/// The Browser's open tabs, counted on its thread.
fn tabCount(host: *browser.BrowserHost) !usize {
    const Count = struct {
        count: usize = 0,
        failed: bool = false,
        fn run(context: ?*anyopaque, b: *browser.Browser) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            const tabs = b.listTabs(b.allocator) catch {
                self.failed = true;
                return;
            };
            defer browser.Browser.freeTabs(b.allocator, tabs);
            self.count = tabs.len;
        }
    };
    var c: Count = .{};
    try host.call(&c, Count.run);
    if (c.failed) return error.ListFailed;
    return c.count;
}

test "remote debugging: the browser's first window is its one page, as headless Chrome starts" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var bad: []const u8 = "";
    const options = try repl.parseOptions(&.{"--remote-debugging-port=0"}, &bad);
    const host = try browser.BrowserHost.start(gpa.allocator(), .{});
    defer host.stop();
    try repl.openFirstWindow(host, options);
    try testing.expectEqual(@as(usize, 1), try tabCount(host));
}

test "remote debugging with a URL: still one page, the first, navigated to it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var bad: []const u8 = "";
    const options = try repl.parseOptions(&.{ "--remote-debugging-port=0", "data:text/html,<title>first</title>" }, &bad);
    const host = try browser.BrowserHost.start(gpa.allocator(), .{});
    defer host.stop();
    try repl.openFirstWindow(host, options);
    try testing.expectEqual(@as(usize, 1), try tabCount(host));
}
