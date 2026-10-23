//! Selection API stringifier, CSS UI 4 §6.1, CSS Contain 2 §4.
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

test "the shared rendering predicate excludes skipped descendants but keeps their root box" {
    try fresh(
        \\target.tabIndex = 0; target.style.contentVisibility = 'hidden'; target.innerHTML = '<input>';
        \\target.focus(); const ownBox = document.activeElement === target;
        \\target.firstChild.focus(); const skipped = document.activeElement !== target.firstChild;
        \\target.style.contentVisibility = 'visible'; target.firstChild.focus();
        \\JSON.stringify([ownBox, skipped, document.activeElement === target.firstChild]);
    , "[true,true,true]");
}
