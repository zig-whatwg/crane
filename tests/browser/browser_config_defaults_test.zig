//! BrowserConfig's defaults are in memory (docs/instances.md: "In memory by
//! default; an optional profile directory persists the Browser's stores"):
//! a Browser left at them writes nothing to disk. They made empty
//! directories under ~/.whatwg/ on every Browser.init, which nothing read.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const BrowserConfig = browser_mod.BrowserConfig;

test "BrowserConfig's default is in memory" {
    const defaults: BrowserConfig = .{};
    try testing.expect(!defaults.persist_storage);
}

test "a Browser at the defaults makes nothing under its storage root" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const root = try std.fs.path.join(testing.allocator, &.{ base, "profile" });
    defer testing.allocator.free(root);

    const browser = try Browser.init(testing.allocator, .{ .storage_root = root, .snapshot_path = "" });
    try browser.navigate("about:blank", .window);
    browser.deinit();
    try testing.expectError(error.FileNotFound, tmp.dir.access(testing.io, "profile", .{}));
}

test "a Browser at the defaults makes nothing under $HOME" {
    // Only where ~/.whatwg/ is not there already: then a Browser that made
    // it would show.
    const home = std.c.getenv("HOME") orelse return;
    const whatwg = try std.fs.path.join(testing.allocator, &.{ std.mem.span(home), ".whatwg" });
    defer testing.allocator.free(whatwg);
    if (std.Io.Dir.cwd().access(testing.io, whatwg, .{})) |_| return else |_| {}
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    browser.deinit();
    try testing.expectError(error.FileNotFound, std.Io.Dir.cwd().access(testing.io, whatwg, .{}));
}
