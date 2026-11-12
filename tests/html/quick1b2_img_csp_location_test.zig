//! HTML "update the image data" fetches after a microtask, when the script
//! that set `src` has returned: a CSP violation of that fetch reports the
//! location of the script that queued the microtask (Firefox's and Safari's
//! mechanism - Gecko's ImageLoadTask captures JSCallingLocation when it is
//! queued; lane quick1 b2). The location is captured only when the img's
//! document has a CSP policy; it is owned by the microtask, then by the
//! request - a superseded update and a cancelled fetch free it
//! (std.testing.allocator).
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

fn open(markup: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "https://quick1.test/page.html" });
    _ = try browser.runEventLoopBlocking(50);
    return browser;
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        const page = browser.current_context orelse return error.NoPage;
        const seen = try page.evaluateScriptToString("JSON.stringify(globalThis.seen)", testing.allocator);
        defer testing.allocator.free(seen);
        std.debug.print("expected true: {s}\nseen: {s}\n", .{ source, seen });
        return error.TestExpectedTrue;
    }
}

// Line 7 sets src once; lines 9-10 set it twice in one script, so the first
// update's microtask is superseded and only line 10's location reports.
const blocked_page =
    \\<!doctype html>
    \\<meta http-equiv="Content-Security-Policy" content="img-src 'none'">
    \\<body><script>
    \\globalThis.seen = [];
    \\document.addEventListener('securitypolicyviolation', e => seen.push({ file: e.sourceFile, line: e.lineNumber, column: e.columnNumber, uri: e.blockedURI }));
    \\const one = document.createElement('img');
    \\one.src = '/one.png';
    \\const two = document.createElement('img');
    \\two.src = '/superseded.png';
    \\two.src = '/two.png';
    \\</script>
;

fn blockedImagesReportTheQueuingScript() !void {
    const browser = try open(blocked_page);
    defer browser.deinit();
    try expectTrue(browser, "seen.length === 2");
    try expectTrue(browser, "seen[0].uri === 'https://quick1.test/one.png' && seen[0].file === 'https://quick1.test/page.html' && seen[0].line === 7 && seen[0].column > 0");
    try expectTrue(browser, "seen[1].uri === 'https://quick1.test/two.png' && seen[1].file === 'https://quick1.test/page.html' && seen[1].line === 10 && seen[1].column > 0");
}

test "a blocked img's violation reports the script that queued its update, the newest of a superseded pair" {
    try onFreshThread(blockedImagesReportTheQueuingScript);
}

// A policy that allows the image: the location rides on the request of a
// fetch that never answers, which a later update cancels.
const allowed_page =
    \\<!doctype html>
    \\<meta http-equiv="Content-Security-Policy" content="style-src 'none'">
    \\<body><script>
    \\globalThis.seen = [];
    \\globalThis.image = new Image();
    \\image.src = 'http://127.0.0.1:65533/never-delivered';
    \\</script>
;

fn cancelledFetchFreesItsLocation() !void {
    const browser = try open(allowed_page);
    defer browser.deinit();
    try expectTrue(browser, "image.complete === false");
    // A newer update cancels the fetch in flight, and the request with it.
    try expectTrue(browser, "image.src = 'http://127.0.0.1:65533/also-never-delivered'; true");
    _ = try browser.runEventLoopBlocking(20);
    try expectTrue(browser, "image.complete === false && seen.length === 0");
}

test "the request of a cancelled img fetch frees the location it carried" {
    try onFreshThread(cancelledFetchFreesItsLocation);
}

// No policy: nothing is captured, and nothing reports.
fn noPolicyCapturesNothing() !void {
    const browser = try open("<!doctype html><body><script>globalThis.seen = []; globalThis.image = new Image(); image.src = 'http://127.0.0.1:65533/never-delivered';</script>");
    defer browser.deinit();
    try expectTrue(browser, "image.complete === false && seen.length === 0");
}

test "an img in a document without a policy captures no location" {
    try onFreshThread(noPolicyCapturesNothing);
}
