//! A dedicated worker's wraps and its realm's end ask nothing of the window
//! thread's tables (lane crashes7).
//!
//! A Browser's InstanceRegistry tables - Node's, Document's - are the window
//! thread's: every entry is made and freed there, and they take no lock
//! (runtime.InstanceRegistry). The wrapper cache asked them about objects of
//! any type: whether an instance is a node in a tree (wrapper_cache.treeOwns,
//! at a realm's end and in its finalizers) and whether it is a document with
//! a default view (engineHoldsWrapper, at every wrap). A worker realm's cache
//! asks both of each of its own objects, none of them nodes, on the worker's
//! thread - so a worker that wrapped objects, or whose realm ended, while its
//! page made and freed nodes and documents read those tables under the
//! window thread's writes. ThreadSanitizer saw it as a data race on the node
//! table's map (hash_map getIndex, InstanceRegistry(.node, ...)) in
//! tests/html/page_retention_test.zig's transferred-port case: 3 of 10 runs
//! on the branch's base, under -Dsanitize-thread -Dmany-browsers (lanes
//! gstate4, crashes7).
//!
//! Each page here runs both sides at once, for long enough that they
//! overlap: the worker wraps thousands of objects of three types and keeps
//! the last of them alive, then is terminated - its realm's end sweeps every
//! entry - while the page makes documents and nodes, appends, empties and
//! collects. Without ThreadSanitizer the case only checks that both sides
//! ran; under it, a read of the window thread's tables from the worker is a
//! report, and the launcher fails the test on it.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");

const page_html = "<!doctype html><body></body>";

/// The worker wraps for 150 ms (three types a turn, the last 3,000 kept for
/// its realm's end) and reports how many; the page makes documents and nodes
/// in every turn until 20 turns after it terminated the worker.
const page_script =
    \\globalThis.pending = 1;
    \\globalThis.reports = [];
    \\(() => {
    \\  const source = "let n = 0, kept = []; onmessage = e => { if (e.data !== 'go') return;" +
    \\    " const until = Date.now() + 150;" +
    \\    " (function wrap() { for (let i = 0; i < 200; i++) { kept.push(new TextEncoder(), new URLSearchParams('a=1'), new Headers()); n += 3; }" +
    \\    "   if (kept.length > 3000) kept.splice(0, kept.length - 3000);" +
    \\    "   if (Date.now() < until) setTimeout(wrap, 0); else postMessage('wrapped ' + n); })(); };";
    \\  const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
    \\  let terminated = false, after = 0, turns = 0;
    \\  worker.onmessage = e => { reports.push(String(e.data)); terminated = true; worker.terminate(); };
    \\  worker.onerror = () => { globalThis.failed = 'worker error'; pending = 0; };
    \\  worker.postMessage('go');
    \\  (function churn() {
    \\    for (let i = 0; i < 40; i++) {
    \\      const d = document.implementation.createHTMLDocument('t');
    \\      d.body.append(d.createElement('p'), document.createElement('i'));
    \\      document.body.append(document.createElement('b'), document.createTextNode('x'));
    \\    }
    \\    document.body.textContent = '';
    \\    if (++turns % 8 === 0) TestUtils.gc();
    \\    if (terminated && ++after > 20) { pending = 0; return; }
    \\    if (turns > 5000) { globalThis.failed = 'the worker never reported'; pending = 0; return; }
    \\    setTimeout(churn, 0);
    \\  })();
    \\})();
;

fn openPage(browser: *browser_mod.Browser) !void {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "about:blank" });
    try page.runScript(page_script);
    var waited: usize = 0;
    while (true) : (waited += 50) {
        _ = try browser.runEventLoopBlocking(50);
        const pending = try page.evaluateScriptToString("String(!!globalThis.pending)", testing.allocator);
        defer testing.allocator.free(pending);
        if (std.mem.eql(u8, pending, "false")) break;
        if (waited >= 60_000) return error.PageNeverSettled;
    }
    const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
    defer testing.allocator.free(failed);
    if (failed.len != 0) {
        std.debug.print("page check failed: {s}\n", .{failed});
        return error.PageCheckFailed;
    }
    const reports = try page.evaluateScriptToString("reports.join(',')", testing.allocator);
    defer testing.allocator.free(reports);
    if (!std.mem.startsWith(u8, reports, "wrapped ")) {
        std.debug.print("the worker reported: [{s}]\n", .{reports});
        return error.WorkerDidNotWrap;
    }
}

fn workerBesidePageChurn() !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    // Four pages: each navigation also ends the page before, with its
    // worker's realm, beside the next page's start.
    for (0..4) |_| try openPage(browser);
}

test "a worker that wraps objects and ends while its page makes and frees nodes and documents reads none of the window thread's tables" {
    try helpers.onFreshThread(workerBesidePageChurn);
}
