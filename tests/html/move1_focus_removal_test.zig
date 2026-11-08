//! HTML removing steps step 2 at the removal, and focus kept by a move: lane
//! move1 batch 1, cause H (tmp/plans/move1-design.md section 3.5).
//!
//! Spec: https://html.spec.whatwg.org/multipage/infrastructure.html#dom-trees

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

// HTML removing steps step 2: the focused area becomes the viewport at the
// removal, so a focused element removed and inserted again before any read is
// no longer focused; a move keeps it focused.
test "a removed focused element is unfocused at the removal, a moved one stays focused" {
    try fresh("<body><section id=a><button id=btn>x</button></section><section id=b></section></body>",
        \\const btn = document.getElementById('btn'), a = document.getElementById('a'), b = document.getElementById('b');
        \\const events = [];
        \\document.addEventListener('focusin', e => events.push('in:' + e.target.id));
        \\document.addEventListener('focusout', e => events.push('out:' + e.target.id));
        \\btn.focus();
        \\b.moveBefore(btn, null);
        \\const afterMove = document.activeElement === btn;
        \\btn.remove(); a.append(btn);
        \\const afterReinsert = document.activeElement === document.body;
        \\btn.focus();
        \\JSON.stringify([afterMove, afterReinsert, document.activeElement === btn, events]);
    , "[true,true,true,[\"in:btn\",\"in:btn\"]]");
}
