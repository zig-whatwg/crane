//! CanvasDrawImage's drawImage() at a different size or a fractional
//! position (HTML 4.12.5.1.15 step 6): resampled - bilinearly, the
//! smoothing default - rather than refused, with the source rectangle
//! clipped to the image and the destination clipped in the same proportion.
//! html/dom/elements/images/bypass-cache-revalidation.html draws an img at
//! 10x10 this way (lane blk2).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://blk2.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        const page = browser.current_context orelse return error.NoPage;
        const log = try page.evaluateScriptToString("JSON.stringify(globalThis.log || null)", testing.allocator);
        defer testing.allocator.free(log);
        std.debug.print("expected true: {s}\nlog: {s}\n", .{ source, log });
        return error.TestExpectedTrue;
    }
}

fn scaledSteps() !void {
    const browser = try open();
    defer browser.deinit();
    // A 2x2 source of four opaque colors, drawn onto 4x4 and 10x10 canvases.
    try run(browser,
        \\globalThis.log = [];
        \\globalThis.source = document.createElement('canvas');
        \\source.width = 2; source.height = 2;
        \\const data = new ImageData(new Uint8ClampedArray([
        \\  255, 0, 0, 255,   0, 255, 0, 255,
        \\  0, 0, 255, 255,   255, 255, 255, 255]), 2, 2);
        \\source.getContext('2d').putImageData(data, 0, 0);
        \\globalThis.pixel = (canvas, x, y) => Array.from(canvas.getContext('2d').getImageData(x, y, 1, 1).data).join(',');
        \\globalThis.target = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
        \\0;
    );
    // Upscaled 2x: each corner pixel samples only its own source pixel.
    try run(browser,
        \\globalThis.up = target(4, 4);
        \\try { up.getContext('2d').drawImage(source, 0, 0, 4, 4); } catch (e) { log.push('up: ' + e.name); }
        \\0;
    );
    try expectTrue(browser, "log.length === 0");
    try expectTrue(browser, "pixel(up, 0, 0) === '255,0,0,255'");
    try expectTrue(browser, "pixel(up, 3, 0) === '0,255,0,255'");
    try expectTrue(browser, "pixel(up, 0, 3) === '0,0,255,255'");
    try expectTrue(browser, "pixel(up, 3, 3) === '255,255,255,255'");
    // Between two source pixels the filter mixes them: (1, 0) is 3/4 red,
    // 1/4 green.
    try expectTrue(browser, "pixel(up, 1, 0) === '191,64,0,255'");
    // A one-color source rectangle stays that color at any scale and at a
    // fractional position; the pixels outside the destination are untouched.
    try run(browser,
        \\globalThis.solid = target(10, 10);
        \\solid.getContext('2d').drawImage(source, 0, 0, 1, 1, 0.5, 0.5, 5, 5);
        \\0;
    );
    try expectTrue(browser, "pixel(solid, 1, 1) === '255,0,0,255'");
    try expectTrue(browser, "pixel(solid, 4, 4) === '255,0,0,255'");
    try expectTrue(browser, "pixel(solid, 6, 6) === '0,0,0,0'");
    // A source rectangle outside the image is clipped, the destination in
    // proportion: half of it (x -2..0) lies left of the image, so the
    // destination starts halfway, at x 4.
    try run(browser,
        \\globalThis.clipped = target(8, 4);
        \\clipped.getContext('2d').drawImage(source, -2, 0, 4, 2, 0, 0, 8, 4);
        \\0;
    );
    try expectTrue(browser, "pixel(clipped, 3, 0) === '0,0,0,0'");
    try expectTrue(browser, "pixel(clipped, 4, 0) === '255,0,0,255'");
    try expectTrue(browser, "pixel(clipped, 7, 3) === '255,255,255,255'");
}

test "drawImage at another size resamples the source, clipped in proportion" {
    try onFreshThread(scaledSteps);
}
