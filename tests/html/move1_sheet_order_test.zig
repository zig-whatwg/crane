//! A moved style sheet owner takes its new place in the sheets' tree order:
//! lane move1 batch 1, cause B (tmp/plans/move1-design.md section 3.2).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#documentorshadowroot-document-or-shadow-root-css-style-sheets

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

// CSSOM 6.2: a document's sheets are in tree order, which a move changes -
// for the document's own sheets, a shadow tree's, and a sheet owner moved
// inside a moved subtree.
test "moveBefore reorders the style sheets it moves" {
    try fresh(
        \\<head><style id=s1>#t { color: rgb(255, 0, 0) }</style><style id=s2>#t { color: rgb(0, 0, 255) }</style></head><body><div id=t></div><div id=holder></div></body>
    ,
        \\const t = document.getElementById('t'), s1 = document.getElementById('s1'), s2 = document.getElementById('s2');
        \\const out = [getComputedStyle(t).color];
        \\document.head.moveBefore(s2, s1);
        \\out.push(getComputedStyle(t).color, [...document.styleSheets].map(s => s.ownerNode.id).join());
        \\const wrapper = document.createElement('div'); document.body.append(wrapper);
        \\wrapper.moveBefore(s2, null); out.push(getComputedStyle(t).color);
        \\document.head.moveBefore(wrapper, s1); out.push(getComputedStyle(t).color);
        \\const host = document.createElement('div'); document.body.append(host);
        \\const root = host.attachShadow({mode: 'open'});
        \\root.innerHTML = '<style id=r1>p { color: rgb(1, 1, 1) }</style><style id=r2>p { color: rgb(2, 2, 2) }</style><p></p>';
        \\const p = root.querySelector('p');
        \\out.push(getComputedStyle(p).color);
        \\root.moveBefore(root.getElementById('r2'), root.getElementById('r1'));
        \\out.push(getComputedStyle(p).color, [...root.styleSheets].map(s => s.ownerNode.id).join());
        \\JSON.stringify(out);
    , "[\"rgb(0, 0, 255)\",\"rgb(255, 0, 0)\",\"s2,s1\",\"rgb(0, 0, 255)\",\"rgb(255, 0, 0)\",\"rgb(2, 2, 2)\",\"rgb(1, 1, 1)\",\"r2,r1\"]");
}
