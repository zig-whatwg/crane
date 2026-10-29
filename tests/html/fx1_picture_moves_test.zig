//! Chrome 156 and Firefox 158 agree that moveBefore updates both picture
//! contexts (integrator probe, 2026-10-27; codex-fetchlater Q27).
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

const Case = enum { img_into_picture, source_between_pictures, source_after_img };

fn script(browser: *browser_mod.Browser, source: []const u8) !void {
    const result = try browser.evaluateScript(source);
    result.release();
}

fn selected(browser: *browser_mod.Browser, predicate: []const u8) !void {
    for (0..100) |_| {
        const result = try browser.evaluateScript(predicate);
        const done = engine.toBoolean(browser.getRealm() orelse return error.NoRealm, result.borrow());
        result.release();
        if (done) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.ImageSelectionDidNotUpdate;
}

fn runCase(kind: Case) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    // Distinct complete resources without an HTTP server or shared fixtures.
    try script(browser,
        \\globalThis.fx1URL = color => 'data:image/svg+xml,' + encodeURIComponent(
        \\  '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1">' +
        \\  '<rect width="1" height="1" fill="' + color + '"/></svg>');
        \\globalThis.fx1Chosen = fx1URL('green');
        \\globalThis.fx1OldFallback = fx1URL('red');
        \\globalThis.fx1NewFallback = fx1URL('blue');
        \\globalThis.fx1Old = document.createElement('picture');
        \\globalThis.fx1New = document.createElement('picture');
        \\globalThis.fx1Source = document.createElement('source');
        \\globalThis.fx1Image = document.createElement('img');
        \\globalThis.fx1Other = document.createElement('img');
        \\fx1Source.srcset = fx1Chosen;
        \\document.body.append(fx1Old, fx1New);
    );
    switch (kind) {
        .img_into_picture => {
            try script(browser,
                \\globalThis.fx1Div = document.createElement('div');
                \\document.body.append(fx1Div);
                \\fx1Div.append(fx1Image);
                \\fx1New.append(fx1Source);
                \\fx1Image.src = fx1OldFallback;
            );
            try selected(browser, "fx1Image.complete && fx1Image.currentSrc === fx1OldFallback");
            try script(browser, "fx1New.moveBefore(fx1Image, null)");
            try selected(browser, "fx1Image.complete && fx1Image.currentSrc === fx1Chosen");
        },
        .source_between_pictures => {
            try script(browser,
                \\fx1Old.append(fx1Source, fx1Image);
                \\fx1New.append(fx1Other);
                \\fx1Image.src = fx1OldFallback;
                \\fx1Other.src = fx1NewFallback;
            );
            try selected(browser, "fx1Image.complete && fx1Image.currentSrc === fx1Chosen && fx1Other.complete && fx1Other.currentSrc === fx1NewFallback");
            try script(browser, "fx1New.moveBefore(fx1Source, fx1Other)");
            try selected(browser, "fx1Image.complete && fx1Image.currentSrc === fx1OldFallback && fx1Other.complete && fx1Other.currentSrc === fx1Chosen");
        },
        .source_after_img => {
            try script(browser,
                \\fx1Old.append(fx1Source, fx1Image);
                \\fx1Image.src = fx1OldFallback;
            );
            try selected(browser, "fx1Image.complete && fx1Image.currentSrc === fx1Chosen");
            try script(browser, "fx1Old.moveBefore(fx1Source, null)");
            try selected(browser, "fx1Image.complete && fx1Image.currentSrc === fx1OldFallback");
        },
    }
}

fn onThread(kind: Case) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(case: Case, out: *anyerror!void) void {
            out.* = runCase(case);
        }
    }.run, .{ kind, &result });
    thread.join();
    try result;
}

test "picture moveBefore selects a source for an img moved from a div" {
    try onThread(.img_into_picture);
}

test "picture moveBefore updates both pictures when a source moves between them" {
    try onThread(.source_between_pictures);
}

test "picture moveBefore reselects after a same-parent source reorder" {
    try onThread(.source_after_img);
}
