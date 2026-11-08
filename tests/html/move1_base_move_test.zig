//! A move that changes the first base element sets the frozen base URL again:
//! lane move1 batch 1, cause J (tmp/plans/move1-design.md section 3.7).
//!
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url

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

// HTML 4.2.3: the document base URL is the frozen base URL of the first base
// element with an href in tree order; a move can change which one that is
// (Blink and Gecko reprocess their base elements on a move).
test "moveBefore sets the frozen base URL again when it changes the first base element" {
    try fresh(
        \\<head><base id=b1 href="https://one.move1.test/"><base id=b2 href="https://two.move1.test/"></head><body><div id=d></div></body>
    ,
        \\const b1 = document.getElementById('b1'), b2 = document.getElementById('b2'), d = document.getElementById('d');
        \\const out = [document.baseURI];
        \\document.head.moveBefore(b2, b1); out.push(document.baseURI);
        \\d.moveBefore(b2, null); out.push(document.baseURI);
        \\document.head.moveBefore(b2, null); out.push(document.baseURI);
        \\JSON.stringify(out);
    , "[\"https://one.move1.test/\",\"https://two.move1.test/\",\"https://one.move1.test/\",\"https://one.move1.test/\"]");
}
