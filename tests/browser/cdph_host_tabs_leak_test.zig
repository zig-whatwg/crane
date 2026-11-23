//! Opening and closing host tabs leaks nothing (lane cdph): every tab's
//! realm, traversable, browsing context and documents go with its close -
//! std.testing.allocator checks the Zig side at the test's end; the engine's
//! side is the regression protocol's and `leaks --atExit`'s (the CDP test
//! pass). Written in the CDP phase (user directive 2026-11-21 5:48 PM ET).

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

test "opening and closing 50 tabs, in creation order and in reverse, leaves the Browser as it was" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    var round: usize = 0;
    while (round < 25) : (round += 1) {
        const a = try browser.createTab(.{ .url = "data:text/html,<title>a</title><script>setTimeout(() => {}, 100000)</script>" });
        const b = try browser.createTab(.{ .url = "data:text/html,<iframe srcdoc='<p>frame'></iframe>" });
        try browser.runEventLoop(5);
        if (round % 2 == 0) {
            try browser.closeTab(a, .{});
            try browser.closeTab(b, .{});
        } else {
            try browser.closeTab(b, .{ .prompt_unload = true });
            try browser.closeTab(a, .{ .prompt_unload = true });
        }
        try testing.expectEqual(@as(usize, 1), browser.traversableCount());
        try testing.expectEqual(@as(usize, 0), browser.tabs.items.len);
    }
}

test "a Browser ended with host tabs still open ends them all" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    _ = try browser.createTab(.{ .url = "data:text/html,one" });
    _ = try browser.createTab(.{ .url = "data:text/html,two" });
    _ = try browser.createTab(.{ .hold_first_navigation = true, .url = "data:text/html,held" });
    try browser.runEventLoop(5);
}
