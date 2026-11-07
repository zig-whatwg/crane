//! CSSOM View geometry reads update style first, as browsers' do: lane
//! move1 batch 1, cause C (tmp/plans/move1-design.md section 3.3).
//!
//! Spec: https://drafts.csswg.org/css-transitions-1/#starting

const std = @import("std");
const Browser = @import("browser").Browser;

fn exercise(comptime html: []const u8, comptime source: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://move1.test/", .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoContext;
    try context.loadHTML("<!doctype html>" ++ html, .{ .base_url = "https://move1.test/" });
    const text = try context.evaluateScriptToString(source, std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn fresh(comptime html: []const u8, comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, result: *?anyerror) void {
            exercise(html, source, want) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &result });
    thread.join();
    if (result) |err| return err;
}

// CSSOM View geometry reads update style first, as every browser's do (Blink
// UpdateStyleAndLayoutForNode): the read establishes the before-change style,
// so the change after it starts a transition. With no read before the change
// there is no before-change style and no transition (CSS Transitions 1 3).
fn transitionAfter(comptime read: []const u8, expected: []const u8) !void {
    try fresh(
        \\<style>.t { transition: margin-left 10s linear; margin-left: 0px }</style>
        \\<body></body>
    ,
        // Made here, so no style resolution before this script can have given it
        // a before-change style.
        \\const a = document.createElement('div'); a.className = 't'; document.body.append(a);
        \\
    ++ read ++
        \\
        \\a.style.marginLeft = '100px';
        \\JSON.stringify(a.getAnimations().map(x => x.transitionProperty));
    , expected);
}

test "getBoundingClientRect updates style, so a later change starts a transition" {
    try transitionAfter("a.getBoundingClientRect();", "[\"margin-left\"]");
}

test "offsetWidth updates style, so a later change starts a transition" {
    try transitionAfter("a.offsetWidth;", "[\"margin-left\"]");
}

test "getClientRects updates style, so a later change starts a transition" {
    try transitionAfter("a.getClientRects();", "[\"margin-left\"]");
}

test "with no read before the change no transition starts" {
    try transitionAfter("", "[]");
}
