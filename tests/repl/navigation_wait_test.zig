//! Scripted input and a navigation the input starts: the next line reads the
//! new page. (Written against the console's oldest API - Console.init and
//! feedLine - so it runs on a console that predates the live page too, where
//! it fails: the console took the next line as soon as the input's result
//! printed, while the navigation was still under way.)
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Console = @import("repl").Console;
const Site = @import("site.zig").Site;

test "after location.href = .. the next line reads the new page: scripted input waits for the navigation its input started" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const a = try site.url(testing.allocator, "/a.html");
    defer testing.allocator.free(a);
    const b = try site.url(testing.allocator, "/b.html");
    defer testing.allocator.free(b);

    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate(a, .window);
    var output: std.Io.Writer.Allocating = .init(testing.allocator);
    defer output.deinit();
    var console = Console.init(testing.allocator, browser, &output.writer);
    defer console.deinit();

    const assign = try std.fmt.allocPrint(testing.allocator, "location.href = '{s}'", .{b});
    defer testing.allocator.free(assign);
    _ = try console.feedLine(assign);
    output.clearRetainingCapacity();
    // No await, no sleep: the next line.
    _ = try console.feedLine("document.title");
    try testing.expectEqualStrings("'B'\n", output.written());
}
