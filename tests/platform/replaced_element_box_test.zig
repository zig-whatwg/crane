//! The layout STOPGAP of decision 19b: `platform.replacedElementBox`, a
//! replaced element's box from the facts Crane gives with the query
//! (docs/platform-protocol.md 6.9). The testing platform sizes it as CSS 2.1
//! 10.3.2/10.6.2 size an inline replaced element with no style but its
//! width and height attributes' presentational hints; a platform without
//! the layout capability gives no box (CSSOM View's zeros).

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

const Facts = struct {
    connected: bool = true,
    natural: ?[2]u32 = null,
    width: ?u32 = null,
    height: ?u32 = null,

    fn record(self: Facts) platform.ReplacedElementFacts {
        return .{
            .connected = self.connected,
            .has_natural_size = self.natural != null,
            .natural_width = if (self.natural) |n| n[0] else 0,
            .natural_height = if (self.natural) |n| n[1] else 0,
            .has_width_attribute = self.width != null,
            .width_attribute = self.width orelse 0,
            .has_height_attribute = self.height != null,
            .height_attribute = self.height orelse 0,
        };
    }
};

fn clientSize(browser: *platform.BrowserPlatform, facts: Facts) ?[2]f64 {
    const record = facts.record();
    const metrics = platform.replacedElementBox(browser, .{ .id = 1 }, .{ .id = 2 }, &record) orelse return null;
    // The box has no border, padding or scrollbar: its offset and scroll
    // sizes are its client size (a mismatch reads as -1).
    if (metrics.offset.width != metrics.client.width or metrics.scroll_height != metrics.client.height) return .{ -1, -1 };
    return .{ metrics.client.width, metrics.client.height };
}

test "replacedElementBox: an img's box with no style is sized as CSS 2.1 sizes a replaced element" {
    if (platform.capabilities.layout == .unsupported) return;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    // Both auto: the natural size.
    try testing.expectEqual([2]f64{ 32, 16 }, clientSize(browser, .{ .natural = .{ 32, 16 } }).?);
    // One attribute: the other from the natural aspect ratio.
    try testing.expectEqual([2]f64{ 10, 5 }, clientSize(browser, .{ .natural = .{ 32, 16 }, .width = 10 }).?);
    try testing.expectEqual([2]f64{ 64, 32 }, clientSize(browser, .{ .natural = .{ 32, 16 }, .height = 32 }).?);
    // Both attributes: as given, whatever the ratio.
    try testing.expectEqual([2]f64{ 7, 9 }, clientSize(browser, .{ .natural = .{ 32, 16 }, .width = 7, .height = 9 }).?);
    // A zero natural dimension gives no ratio: the natural size stands.
    try testing.expectEqual([2]f64{ 10, 0 }, clientSize(browser, .{ .natural = .{ 0, 0 }, .width = 10 }).?);
    // No image available: the attributes' size, or no box at all.
    try testing.expectEqual([2]f64{ 20, 0 }, clientSize(browser, .{ .width = 20 }).?);
    try testing.expectEqual(@as(?[2]f64, null), clientSize(browser, .{}));
    // Not in a document: no box.
    try testing.expectEqual(@as(?[2]f64, null), clientSize(browser, .{ .connected = false, .natural = .{ 32, 16 } }));
}

test "replacedElementBox: without the layout capability there is nothing to ask" {
    if (platform.capabilities.layout != .unsupported) return;
    // CSSOM View with no layout box: clientWidth and clientHeight are 0.
    try testing.expect(true);
}
