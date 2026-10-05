//! HTML "allowed to perform a navigation or history update", the navigable's
//! implementation-defined rate limit (src/html/window/browsing_context.zig):
//! "this can return blocked if invoked too many times within a certain
//! timespan". Crane's is Blink's NavigationRateLimiter: 200 navigations and
//! history updates per navigable, then blocked until 10 seconds have passed
//! since the window began. WPT's *_too_many_calls.optional.html files call
//! pushState(), replaceState(), history.go() and location.hash= 500 times in
//! a row and expect the later calls to be ignored.

const std = @import("std");
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;

const second: u64 = std.time.ns_per_s;

test "the first 200 navigations or history updates in a window are allowed, the next is blocked" {
    const bc = try BrowsingContext.initTopLevel(std.testing.allocator);
    defer bc.deinit();
    const start: u64 = 5 * second;
    var i: usize = 0;
    while (i < BrowsingContext.navigation_rate_limit) : (i += 1) {
        try std.testing.expect(bc.allowedToNavigateOrUpdateHistoryAt(start + i));
    }
    try std.testing.expect(!bc.allowedToNavigateOrUpdateHistoryAt(start + i));
    try std.testing.expect(!bc.allowedToNavigateOrUpdateHistoryAt(start + 9 * second));
}

test "the limit resets once the window has passed" {
    const bc = try BrowsingContext.initTopLevel(std.testing.allocator);
    defer bc.deinit();
    const start: u64 = 1;
    var i: usize = 0;
    while (i <= BrowsingContext.navigation_rate_limit) : (i += 1) {
        _ = bc.allowedToNavigateOrUpdateHistoryAt(start);
    }
    try std.testing.expect(!bc.allowedToNavigateOrUpdateHistoryAt(start + 10 * second - 1));
    try std.testing.expect(bc.allowedToNavigateOrUpdateHistoryAt(start + 10 * second));
    try std.testing.expect(bc.allowedToNavigateOrUpdateHistoryAt(start + 10 * second + 1));
}

test "each navigable has its own limit" {
    const allocator = std.testing.allocator;
    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();
    const child = try BrowsingContext.initChild(allocator, top);
    defer child.deinit();
    var i: usize = 0;
    while (i <= BrowsingContext.navigation_rate_limit) : (i += 1) {
        _ = child.allowedToNavigateOrUpdateHistoryAt(1);
    }
    try std.testing.expect(!child.allowedToNavigateOrUpdateHistoryAt(2));
    try std.testing.expect(top.allowedToNavigateOrUpdateHistoryAt(2));
}
