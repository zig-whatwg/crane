//! HTMLCanvasElement.toDataURL and toBlob (HTML 4.12.5.1) over a serialization
//! of the canvas's bitmap as a file (4.12.5.5): PNG through the platform's
//! `image_encoding` capability, a "data:," for a bitmap without pixels, PNG
//! for a type the platform does not encode, straight alpha in the file from
//! the premultiplied bitmap - read back by an img and drawn again - and
//! toBlob's callback in a queued task with an image/png Blob, or null.
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
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://quick1.test/page.html" });
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

/// Run the event loop until `condition` holds, or about a second has passed.
fn waitFor(browser: *browser_mod.Browser, condition: []const u8) !void {
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        const held = try browser.evaluateScript(condition);
        defer held.release();
        if (engine.toBoolean(browser.getRealm().?, held.borrow())) return;
        _ = try browser.runEventLoopBlocking(20);
    }
    try expectTrue(browser, condition);
}

fn toDataUrlSteps() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.log = [];
        \\globalThis.header = url => {
        \\  const bytes = atob(url.slice(url.indexOf(',') + 1));
        \\  const word = at => ((bytes.charCodeAt(at) << 24) | (bytes.charCodeAt(at + 1) << 16) | (bytes.charCodeAt(at + 2) << 8) | bytes.charCodeAt(at + 3)) >>> 0;
        \\  return { png: bytes.slice(0, 8) === '\x89PNG\r\n\x1a\n', width: word(16), height: word(20) };
        \\};
        \\globalThis.blank = document.createElement('canvas');
        \\0;
    );
    // A canvas with no context: transparent black of its attributes' size.
    try expectTrue(browser, "blank.toDataURL().startsWith('data:image/png;base64,')");
    try expectTrue(browser, "(h => h.png && h.width === 300 && h.height === 150)(header(blank.toDataURL()))");
    // Types: lowercased, then PNG for one the platform does not encode, or
    // one with parameters.
    try expectTrue(browser, "blank.toDataURL('IMAGE/PNG').startsWith('data:image/png;base64,')");
    try expectTrue(browser, "blank.toDataURL('image/jpeg', 0.5).startsWith('data:image/png;base64,')");
    try expectTrue(browser, "blank.toDataURL('image/png;foo=bar').startsWith('data:image/png;base64,')");
    try expectTrue(browser, "blank.toDataURL('image/example', 'not a number') === blank.toDataURL()");
    // Step 2: no pixels.
    try expectTrue(browser, "(() => { const c = document.createElement('canvas'); c.width = 0; return c.toDataURL() === 'data:,'; })()");
    try expectTrue(browser, "(() => { const c = document.createElement('canvas'); c.height = 0; c.getContext('2d'); return c.toDataURL() === 'data:,'; })()");
}

test "toDataURL: a PNG data: URL of the bitmap's size, PNG for any other type, data:, without pixels" {
    try onFreshThread(toDataUrlSteps);
}

fn roundTrip() !void {
    const browser = try open();
    defer browser.deinit();
    // Opaque, half-transparent and fully transparent pixels: the last is
    // premultiplied to transparent black, whose colour no file can keep.
    try run(browser,
        \\globalThis.log = [];
        \\globalThis.source = document.createElement('canvas');
        \\source.width = 3; source.height = 2;
        \\const context = source.getContext('2d');
        \\const data = context.createImageData(3, 2);
        \\data.data.set([255, 0, 0, 255,  0, 255, 0, 255,  0, 0, 255, 255,
        \\               10, 20, 30, 255,  255, 255, 255, 128,  255, 0, 0, 0]);
        \\context.putImageData(data, 0, 0);
        \\globalThis.expected = Array.from(context.getImageData(0, 0, 3, 2).data);
        \\globalThis.image = new Image();
        \\image.onload = () => {
        \\  const target = document.createElement('canvas');
        \\  target.width = 3; target.height = 2;
        \\  const t = target.getContext('2d');
        \\  t.drawImage(image, 0, 0);
        \\  globalThis.actual = Array.from(t.getImageData(0, 0, 3, 2).data);
        \\};
        \\image.onerror = () => log.push('error');
        \\image.src = source.toDataURL();
        \\0;
    );
    try waitFor(browser, "globalThis.actual !== undefined || log.length > 0");
    try expectTrue(browser, "expected[23] === 0 && expected[20] === 0");
    try expectTrue(browser, "JSON.stringify(actual) === JSON.stringify(expected)");
}

test "toDataURL's PNG reads back through an img to the canvas's own pixels" {
    try onFreshThread(roundTrip);
}

fn toBlobSteps() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.log = [];
        \\const c = document.createElement('canvas');
        \\c.width = 4; c.height = 4;
        \\c.toBlob(blob => log.push(['png', blob instanceof Blob, blob.type, blob.size > 8]));
        \\c.toBlob(blob => log.push(['jpeg', blob.type]), 'image/jpeg', 0.9);
        \\const empty = document.createElement('canvas');
        \\empty.width = 0;
        \\empty.toBlob(blob => log.push(['empty', blob]));
        \\c.toBlob(() => { throw new Error('reported, not thrown'); });
        \\c.toBlob(() => log.push(['after']));
        \\log.push('sync');
        \\0;
    );
    // The callbacks run in tasks, after the script that asked, in order;
    // one that throws is reported and the next still runs.
    try waitFor(browser, "log.length === 5");
    try expectTrue(browser, "log[0] === 'sync'");
    try expectTrue(browser, "JSON.stringify(log[1]) === JSON.stringify(['png', true, 'image/png', true])");
    try expectTrue(browser, "JSON.stringify(log[2]) === JSON.stringify(['jpeg', 'image/png'])");
    try expectTrue(browser, "JSON.stringify(log[3]) === JSON.stringify(['empty', null])");
    try expectTrue(browser, "JSON.stringify(log[4]) === JSON.stringify(['after'])");
}

test "toBlob: an image/png Blob, or null without pixels, handed over in a queued task" {
    try onFreshThread(toBlobSteps);
}

fn pendingToBlobAtTeardown() !void {
    const browser = try open();
    defer browser.deinit();
    // The task still holds its callback and file when the Browser ends.
    try run(browser, "document.createElement('canvas').toBlob(() => {}); 0;");
}

test "a toBlob task still queued when the Browser ends frees its callback and file" {
    try onFreshThread(pendingToBlobAtTeardown);
}
