//! Allocator hardening, batch B, test B6 (the B1 merge's): the general
//! partitions are made and freed on every agent's thread at once
//! (tmp/plans/allocator-hardening-design.md 3.7: each agent's cache an
//! array of slot addresses, refilled and flushed under the partition's
//! mutex; a free goes to the FREEING thread's cache, as PartitionAlloc's
//! thread cache takes it).
//!
//! The window and four dedicated workers each make and drop strings and
//! records of many classes while they message one another: a message's
//! payload is made on its sender's thread and freed on its receiver's, so
//! the blocks cross threads both ways ([INV] 9: port messages freed by the
//! receiver). The second case ends the Browser while all four still send:
//! BrowserScope.deinit races their last frees, and each agent's cache must
//! be flushed at its agent's end, before the heap's.
//!
//! Green today (libc's malloc is thread-safe): this pins that B1's per-agent
//! caches keep it so. Under -Dsanitize-thread a race on a cache or on the
//! span state is a report, and the launcher fails the test on it. Nothing in
//! src/ forks (no fork, vfork or posix_spawn), so the design's fork case does
//! not apply.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

const page_html = "<!doctype html><body></body>";

/// Four workers; each, told 'go', sends for `ms` milliseconds: strings of
/// 16 B to 4 KiB and arrays of small records, and frees what the page sends
/// back. The page answers every message with a string of its own and makes
/// and drops nodes and strings between turns.
fn pageScript(comptime ms: u32) []const u8 {
    return std.fmt.comptimePrint(
        \\globalThis.pending = 4;
        \\globalThis.sent = 0;
        \\(() => {{
        \\  const source = "let n = 0, got = 0; onmessage = e => {{ if (e.data !== 'go') {{ got++; return; }}" +
        \\    " const until = Date.now() + {d};" +
        \\    " (function send() {{ for (let i = 0; i < 50; i++) {{ const size = 16 << (i % 9);" +
        \\    "   postMessage(['s'.repeat(size), [{{ a: i, b: 'r' + i }}, {{ c: [i, i + 1] }}]]); n++; }}" +
        \\    "   if (Date.now() < until) setTimeout(send, 0); else postMessage('done ' + n + ' ' + got); }})(); }};";
        \\  const url = URL.createObjectURL(new Blob([source], {{ type: 'text/javascript' }}));
        \\  globalThis.workers = [];
        \\  for (let w = 0; w < 4; w++) {{
        \\    const worker = new Worker(url);
        \\    worker.onmessage = e => {{
        \\      if (typeof e.data === 'string') {{ pending--; return; }}
        \\      sent++;
        \\      worker.postMessage('p'.repeat(16 << (sent % 9)));
        \\      if (sent % 64 === 0) {{ document.body.append(document.createElement('i'), document.createTextNode('t'.repeat(sent % 300))); document.body.textContent = ''; }}
        \\    }};
        \\    worker.onerror = () => {{ globalThis.failed = 'worker error'; pending = 0; }};
        \\    workers.push(worker);
        \\  }}
        \\  for (const worker of workers) worker.postMessage('go');
        \\}})();
    , .{ms});
}

fn open(browser: *browser_mod.Browser, script: []const u8) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "about:blank" });
    try page.runScript(script);
    return page;
}

fn readNumber(page: *browser_mod.Context, source: []const u8) !u64 {
    const text = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(text);
    return std.fmt.parseInt(u64, text, 10);
}

fn failure(page: *browser_mod.Context) !void {
    const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
    defer testing.allocator.free(failed);
    if (failed.len != 0) {
        std.debug.print("B6: {s}\n", .{failed});
        return error.PageFailed;
    }
}

test "B6: the window and four workers make and free general blocks across threads at once" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const page = try open(browser, comptime pageScript(200));
    var waited: usize = 0;
    while (try readNumber(page, "String(globalThis.pending)") != 0) : (waited += 50) {
        _ = try browser.runEventLoopBlocking(50);
        if (waited >= 60_000) return error.WorkersNeverReported;
    }
    try failure(page);
    // Every worker sent, and the page answered: blocks crossed both ways.
    try testing.expect(try readNumber(page, "String(globalThis.sent)") >= 4);
}

test "B6: a Browser that ends while four workers still send and free ends cleanly" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    var ended = false;
    defer if (!ended) browser.deinit();
    // Long enough that every worker still sends when the Browser ends.
    const page = try open(browser, comptime pageScript(10_000));
    var waited: usize = 0;
    while (try readNumber(page, "String(globalThis.sent)") < 400) : (waited += 20) {
        _ = try browser.runEventLoopBlocking(20);
        if (waited >= 60_000) return error.WorkersNeverSent;
    }
    try failure(page);
    // The end: each worker's agent ends (and, from B1, flushes its cache)
    // while its last messages are made and freed, then the heap goes.
    ended = true;
    browser.deinit();
}
