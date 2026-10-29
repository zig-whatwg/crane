//! Lane rendering1 B5: the display's refresh interval, which Crane's frame
//! clock puts rendering opportunities on (docs/platform-protocol.md 6.10.4).
const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

test "the display refreshes at 60 Hz unless the platform knows better" {
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    // The built-in platforms (and the testing platform the WPT runner binds)
    // know no display: 60 Hz, so WPT's frames are deterministic intervals.
    try testing.expectEqual(@as(u64, 16_666_667), platform.displayRefreshInterval(browser, 0));
    try testing.expectEqual(@as(u64, 16_666_667), platform.displayRefreshInterval(browser, 7));
}
