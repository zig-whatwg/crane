//! Values4 root metrics pass through the style engine without a second cascade.
const std = @import("std");
const Browser = @import("browser").Browser;

fn exercise(comptime source: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://cv1.test/", .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoContext;
    try context.loadHTML("<!doctype html><body><div id='target'></div></body>", .{ .base_url = "https://cv1.test/" });
    const text = try context.evaluateScriptToString(
        \\function selectText(node) {
        \\  const range = document.createRange(); range.selectNodeContents(node);
        \\  getSelection().removeAllRanges(); getSelection().addRange(range);
        \\  return getSelection().toString();
        \\}
    ++ source, std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn fresh(comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, result: *?anyerror) void {
            exercise(source, want) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &result });
    thread.join();
    if (result) |err| return err;
}

test "root font metrics reach descendant ch and line height computations" {
    try fresh(
        \\document.documentElement.style.cssText = 'font-size:20px;line-height:30px;writing-mode:vertical-rl;text-orientation:upright';
        \\target.style.cssText = 'width:calc(1rch);height:calc(2rlh)';
        \\JSON.stringify([getComputedStyle(target).width, getComputedStyle(target).height]);
    , "[\"20px\",\"60px\"]");
}
