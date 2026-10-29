//! Q31's 2026-10-27 browser probe: finite negative math clamps to zero;
//! nonfinite sizes skip to the next entry (Chrome 156 and Safari 27).
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

const Selected = enum { first, middle, last };

fn run(comptime size: []const u8, comptime expected: Selected, comptime use_source: bool) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const setup =
        \\globalThis.fx1URL = color => 'data:image/svg+xml,' + encodeURIComponent(
        \\  '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1">' +
        \\  '<rect width="1" height="1" fill="' + color + '"/></svg>');
        \\globalThis.fx1First = fx1URL('red');
        \\globalThis.fx1Middle = fx1URL('green');
        \\globalThis.fx1Last = fx1URL('blue');
        \\globalThis.fx1Picture = document.createElement('picture');
        \\globalThis.fx1Source = document.createElement('source');
        \\globalThis.fx1Image = document.createElement('img');
        \\fx1Picture.append(fx1Source, fx1Image);
        \\document.body.append(fx1Picture);
        \\const scale = Math.ceil(devicePixelRatio);
    ++ (if (use_source) "const owner = fx1Source;" else "const owner = fx1Image;") ++
        "owner.sizes = '" ++ size ++ ", 100px';" ++
        \\owner.srcset = fx1First + ' ' + (30 * scale) + 'w, ' +
        \\  fx1Middle + ' ' + (100 * scale) + 'w, ' + fx1Last + ' ' + (1000 * scale) + 'w';
    ;
    const result = try browser.evaluateScript(setup);
    result.release();
    const predicate = "fx1Image.complete && fx1Image.currentSrc === " ++ switch (expected) {
        .first => "fx1First",
        .middle => "fx1Middle",
        .last => "fx1Last",
    };
    for (0..100) |_| {
        const current = try browser.evaluateScript(predicate);
        const matches = engine.toBoolean(browser.getRealm() orelse return error.NoRealm, current.borrow());
        current.release();
        if (matches) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.WrongSizesSelection;
}

fn onThread(comptime size: []const u8, comptime expected: Selected, comptime use_source: bool) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn start(out: *anyerror!void) void {
            out.* = run(size, expected, use_source);
        }
    }.start, .{&result});
    thread.join();
    try result;
}

test "img sizes calc(-1px) selects the first candidate" {
    try onThread("calc(-1px)", .first, false);
}

test "img sizes -1px selects the middle candidate" {
    try onThread("-1px", .middle, false);
}

test "img sizes calc(infinity * 1px) selects the middle candidate" {
    try onThread("calc(infinity * 1px)", .middle, false);
}

test "img sizes calc(-infinity * 1px) selects the middle candidate" {
    try onThread("calc(-infinity * 1px)", .middle, false);
}

test "img sizes calc(NaN * 1px) selects the middle candidate" {
    try onThread("calc(NaN * 1px)", .middle, false);
}

test "img sizes min(infinity * 1px, 100px) selects the middle candidate" {
    try onThread("min(infinity * 1px, 100px)", .middle, false);
}

test "img sizes 0px selects the first candidate" {
    try onThread("0px", .first, false);
}

test "img sizes 100px selects the middle candidate" {
    try onThread("100px", .middle, false);
}

test "img sizes 1000000px selects the last candidate" {
    try onThread("1000000px", .last, false);
}

test "source sizes calc(-1px) selects the first candidate" {
    try onThread("calc(-1px)", .first, true);
}

test "source sizes -1px selects the middle candidate" {
    try onThread("-1px", .middle, true);
}

test "source sizes calc(infinity * 1px) selects the middle candidate" {
    try onThread("calc(infinity * 1px)", .middle, true);
}

test "source sizes calc(-infinity * 1px) selects the middle candidate" {
    try onThread("calc(-infinity * 1px)", .middle, true);
}

test "source sizes calc(NaN * 1px) selects the middle candidate" {
    try onThread("calc(NaN * 1px)", .middle, true);
}

test "source sizes min(infinity * 1px, 100px) selects the middle candidate" {
    try onThread("min(infinity * 1px, 100px)", .middle, true);
}

test "source sizes 0px selects the first candidate" {
    try onThread("0px", .first, true);
}

test "source sizes 100px selects the middle candidate" {
    try onThread("100px", .middle, true);
}

test "source sizes 1000000px selects the last candidate" {
    try onThread("1000000px", .last, true);
}
