//! Q39's cache-busted browser probe, 2026-10-27: large literal lengths
//! saturate; finite inputs overflowing in calc() saturate in Chrome/Firefox.
//! Q40 pins finite keyword branches and nonfinite mixed branches separately.
//! Q31's explicit infinity/NaN keyword cases remain separate regressions.
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
        "const marker = '" ++ size ++ (if (use_source) "source';" else "img';") ++
        \\globalThis.fx1OverflowURL = color => 'data:image/svg+xml,' + encodeURIComponent(
        \\  '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><title>' + marker + '</title>' +
        \\  '<rect width="1" height="1" fill="' + color + '"/></svg>');
        \\globalThis.fx1OverflowFirst = fx1OverflowURL('red');
        \\globalThis.fx1OverflowMiddle = fx1OverflowURL('green');
        \\globalThis.fx1OverflowLast = fx1OverflowURL('blue');
        \\globalThis.fx1OverflowPicture = document.createElement('picture');
        \\globalThis.fx1OverflowSource = document.createElement('source');
        \\globalThis.fx1OverflowImage = document.createElement('img');
        \\fx1OverflowPicture.append(fx1OverflowSource, fx1OverflowImage);
        \\document.body.append(fx1OverflowPicture);
        \\const scale = Math.ceil(devicePixelRatio);
        ++ (if (use_source) "const owner = fx1OverflowSource;" else "const owner = fx1OverflowImage;") ++
        "owner.sizes = '" ++ size ++ ", 100px';" ++
        \\owner.srcset = fx1OverflowFirst + ' ' + (30 * scale) + 'w, ' +
        \\  fx1OverflowMiddle + ' ' + (100 * scale) + 'w, ' + fx1OverflowLast + ' ' + (1000 * scale) + 'w';
        ;
    const result = try browser.evaluateScript(setup);
    result.release();
    const predicate = "fx1OverflowImage.complete && fx1OverflowImage.currentSrc === " ++ switch (expected) {
        .first => "fx1OverflowFirst",
        .middle => "fx1OverflowMiddle",
        .last => "fx1OverflowLast",
    };
    for (0..100) |_| {
        const current = try browser.evaluateScript(predicate);
        const matches = engine.toBoolean(browser.getRealm() orelse return error.NoRealm, current.borrow());
        current.release();
        if (matches) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.WrongSizesOverflowSelection;
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

test "img sizes finite huge px selects the largest candidate" {
    try onThread("1e308px", .last, false);
}

test "img sizes inches overflowing in px selects the largest candidate" {
    try onThread("1e308in", .last, false);
}

test "img sizes centimeters overflowing in px selects the largest candidate" {
    try onThread("1e308cm", .last, false);
}

test "img sizes viewport width overflowing in px selects the largest candidate" {
    try onThread("1e308vw", .last, false);
}

test "img sizes literal overflowing f64 selects the largest candidate" {
    try onThread("1e309px", .last, false);
}

test "img sizes finite math input overflowing in px selects the largest candidate" {
    try onThread("calc(1e308in)", .last, false);
}

test "img sizes 100px overflow control selects the middle candidate" {
    try onThread("100px", .middle, false);
}

test "source sizes finite huge px selects the largest candidate" {
    try onThread("1e308px", .last, true);
}

test "source sizes inches overflowing in px selects the largest candidate" {
    try onThread("1e308in", .last, true);
}

test "source sizes centimeters overflowing in px selects the largest candidate" {
    try onThread("1e308cm", .last, true);
}

test "source sizes viewport width overflowing in px selects the largest candidate" {
    try onThread("1e308vw", .last, true);
}

test "source sizes literal overflowing f64 selects the largest candidate" {
    try onThread("1e309px", .last, true);
}

test "source sizes finite math input overflowing in px selects the largest candidate" {
    try onThread("calc(1e308in)", .last, true);
}

test "source sizes 100px overflow control selects the middle candidate" {
    try onThread("100px", .middle, true);
}

test "img sizes a finite infinity-keyword branch selects the first candidate" {
    try onThread("min(infinity * 1px, 30px)", .first, false);
}

test "img sizes a keyword plus an overflowing branch selects the fallback" {
    try onThread("max(min(infinity * 1px, 30px), 1e308in)", .middle, false);
}

test "img sizes an overflowing numeric token inside math saturates" {
    try onThread("calc(1e309px)", .last, false);
}

test "img sizes a finite branch containing numeric overflow selects the first candidate" {
    try onThread("min(1e308in, 30px)", .first, false);
}

test "source sizes a finite infinity-keyword branch selects the first candidate" {
    try onThread("min(infinity * 1px, 30px)", .first, true);
}

test "source sizes a keyword plus an overflowing branch selects the fallback" {
    try onThread("max(min(infinity * 1px, 30px), 1e308in)", .middle, true);
}

test "source sizes an overflowing numeric token inside math saturates" {
    try onThread("calc(1e309px)", .last, true);
}

test "source sizes a finite branch containing numeric overflow selects the first candidate" {
    try onThread("min(1e308in, 30px)", .first, true);
}

test "img sizes positive division by zero selects the fallback" {
    try onThread("calc(1px / 0)", .middle, false);
}

test "img sizes negative division by zero selects the fallback" {
    try onThread("calc(-1px / 0)", .middle, false);
}

test "img sizes zero divided by zero selects the fallback" {
    try onThread("calc(0px / 0)", .middle, false);
}

test "img sizes arithmetic overflow selects the largest candidate" {
    try onThread("calc(1e308px * 1e308)", .last, false);
}

test "img sizes overflow cancellation selects the zero-size candidate" {
    try onThread("calc(1e308in - 1e308in)", .first, false);
}

test "img sizes division by zero in a finite branch still selects the fallback" {
    try onThread("min(30px, 1px / 0)", .middle, false);
}

test "source sizes positive division by zero selects the fallback" {
    try onThread("calc(1px / 0)", .middle, true);
}

test "source sizes negative division by zero selects the fallback" {
    try onThread("calc(-1px / 0)", .middle, true);
}

test "source sizes zero divided by zero selects the fallback" {
    try onThread("calc(0px / 0)", .middle, true);
}

test "source sizes arithmetic overflow selects the largest candidate" {
    try onThread("calc(1e308px * 1e308)", .last, true);
}

test "source sizes overflow cancellation selects the zero-size candidate" {
    try onThread("calc(1e308in - 1e308in)", .first, true);
}

test "source sizes division by zero in a finite branch still selects the fallback" {
    try onThread("min(30px, 1px / 0)", .middle, true);
}
