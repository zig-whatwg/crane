//! Lane engine1: where inline script reports from, and when a module
//! script's error is reported.
//!
//! - The HTML parser records where each inline script's text starts (its
//!   position after the start tag) and "run a classic script" / "create a
//!   JavaScript module script" compile the text there (engine
//!   ScriptSource.embedded, parseModule's start): what it throws reports
//!   the document's lines, and a blocked inline script's or style's CSP
//!   violation is located there when no script runs.
//! - HTML "run a module script" step 8 reports a rejected evaluation "upon
//!   rejection": a promise job in step 9's checkpoint, so two error
//!   listeners both run before either's microtasks - the window now as the
//!   worker always did (microtasks/checkpoint-after-window-onerror-module).
//!
//! Each case runs on a thread of its own: a Browser's per-thread state.
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

fn open(html: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = "https://engine1.test/page.html" });
    return browser;
}

/// `source`'s value as a string; the caller frees it.
fn text(browser: *browser_mod.Browser, source: []const u8) ![]u8 {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToDOMString(realm, held.borrow(), testing.allocator);
}

fn expectText(browser: *browser_mod.Browser, source: []const u8, expected: []const u8) !void {
    const got = try text(browser, source);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

/// Run the page's event loop until `source` is not "pending".
fn waitFor(browser: *browser_mod.Browser, source: []const u8, expected: []const u8) !void {
    for (0..200) |_| {
        const got = try text(browser, source);
        defer testing.allocator.free(got);
        if (!std.mem.eql(u8, got, "pending")) return testing.expectEqualStrings(expected, got);
        _ = try browser.runEventLoopBlocking(5);
    }
    return error.TimedOut;
}

// Line 1 is the doctype; the throwing script's text starts on line 4 after
// `<script>` (column 9), and throws on its line 2 (the document's line 5) at
// column 3; the next one throws on its first line, at column 9 + 4.
const classic_page =
    \\<!doctype html>
    \\<script>window.reports = [];
    \\window.onerror = (m, u, line, column) => { reports.push(line + ':' + column); return true; };</script>
    \\<script>
    \\  throw new Error('line 5');
    \\</script>
    \\<script>    throw new Error('line 7');</script>
;

fn classicErrors() !void {
    const browser = try open(classic_page);
    defer browser.deinit();
    try expectText(browser, "reports.join(' ')", "5:3 7:13");
}

test "an inline classic script reports what it throws at its document line and column" {
    try onFreshThread(classicErrors);
}

const csp_page =
    \\<!doctype html>
    \\<meta http-equiv="Content-Security-Policy" content="script-src 'nonce-n'; style-src 'nonce-n'">
    \\<script nonce="n">window.seen = []; document.addEventListener('securitypolicyviolation', e => seen.push(e.target.localName + '@' + e.lineNumber + ':' + e.columnNumber));</script>
    \\<script>var blocked = 1;</script>
    \\  <style>p { color: red }</style>
;

fn cspBlockedInline() !void {
    const browser = try open(csp_page);
    defer browser.deinit();
    // The violations are queued tasks.
    try waitFor(browser, "seen.length < 2 ? 'pending' : seen.join(' ')", "script@4:9 style@5:10");
}

test "a blocked inline script or style is located where its text starts when no script runs" {
    try onFreshThread(cspBlockedInline);
}

// checkpoint-after-error-event.js as an inline module: a graph with no
// imports whose evaluation throws synchronously.
const module_page =
    \\<!doctype html>
    \\<script>window.log = [];
    \\addEventListener('error', () => { log.push('handler 1'); Promise.resolve().then(() => log.push('handler 1 promise')); });
    \\addEventListener('error', () => { log.push('handler 2'); Promise.resolve().then(() => log.push('handler 2 promise')); });
    \\addEventListener('error', e => { e.preventDefault(); log.push('line ' + e.lineno); });</script>
    \\<script type="module">
    \\Promise.resolve().then(() => log.push('evaluation microtask'));
    \\throw new Error('module');</script>
;

fn moduleErrorOrder() !void {
    const browser = try open(module_page);
    defer browser.deinit();
    // Module scripts run after the parse: wait for the report.
    try waitFor(
        browser,
        "log.length < 6 ? 'pending' : log.join(', ')",
        "evaluation microtask, handler 1, handler 2, line 8, handler 1 promise, handler 2 promise",
    );
}

test "a window module script's rejection is reported upon rejection, both handlers before their microtasks" {
    try onFreshThread(moduleErrorOrder);
}
