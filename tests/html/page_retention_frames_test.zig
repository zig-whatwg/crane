//! Lane pageretention1: a navigated frame's old documents give their slots
//! back once their realm has retired - and a node of them the parent page
//! still holds keeps its slot, and reads as a node of an inactive document.
//!
//! A GUARD, green before and after the lane's fixes: it was written for the
//! WPT browsing-the-web lists' remaining html/head/body (unwrapped, torn
//! down, kept: 52 of each a pass of 42 files after the lane's other fixes)
//! on the hypothesis that a retired realm's nodes torn down outside a
//! coordinated teardown keep their slots - and it does not reproduce that
//! remainder, which comes from HTTP-loaded frames a native test cannot make.
//! What it pins: a frame navigated twice per page leaves no document parts
//! behind; a node of the first document the parent keeps keeps its slot and
//! reads 'one' from its own inactive document; and impostors of the second
//! document's types, made between the deferred teardown queue's slices that
//! free that document, are never touched.
//!
//! One Browser per test, each on a thread of its own (tests/html is one
//! executable; a Browser's agent belongs to the thread that made it), on
//! std.testing.allocator.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

fn count(browser: *browser_mod.Browser, names: []const []const u8) usize {
    var live: usize = 0;
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            for (names) |name| {
                if (std.mem.eql(u8, instance.vtable.name, name)) live += 1;
            }
        }
    }
    return live;
}

/// Run the page's tasks until `globalThis.pending` clears (bounded at 10 s);
/// never a fixed delay.
fn settle(browser: *browser_mod.Browser) !void {
    const page = browser.current_context orelse return error.NoPage;
    var waited: usize = 0;
    while (true) : (waited += 50) {
        _ = try browser.runEventLoopBlocking(50);
        const pending = try page.evaluateScriptToString("String(!!globalThis.pending)", testing.allocator);
        defer testing.allocator.free(pending);
        if (std.mem.eql(u8, pending, "false")) return;
        if (waited >= 10_000) return error.PageNeverSettled;
    }
}

fn check(browser: *browser_mod.Browser) !void {
    const page = browser.current_context orelse return error.NoPage;
    const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
    defer testing.allocator.free(failed);
    if (failed.len != 0) {
        std.debug.print("page check failed: {s}\n", .{failed});
        return error.PageCheckFailed;
    }
}

/// A page that navigates a frame twice (three documents), keeps `kept` - a
/// node of the first document, wrapped in the frame's realm, read by the
/// parent - and lets the rest go: the second document, 3,000 elements, is
/// torn down over several slices of the deferred teardown queue.
const navigate_twice =
    \\globalThis.pending = 1;
    \\const f = document.body.appendChild(document.createElement('iframe'));
    \\let loads = 0;
    \\f.onload = () => {
    \\  const text = f.contentDocument.body.textContent;
    \\  if (++loads === 1) { globalThis.kept = f.contentDocument.body.firstChild; f.srcdoc = '<p>two</p>' + '<i>x</i>'.repeat(3000); }
    \\  else if (loads === 2) f.srcdoc = '<p>three</p>';
    \\  else { if (text !== 'three') failed = 'not navigated: ' + text; pending = 0; }
    \\};
    \\f.srcdoc = '<p>one</p>';
;

fn openPage(browser: *browser_mod.Browser) !void {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try page.runScript(navigate_twice);
    try settle(browser);
    // The old documents' realms retire; the collector takes what script let
    // go, and the deferred teardown queue frees it between tasks.
    try page.runScript("globalThis.pending = 1; TestUtils.gc(); TestUtils.gc(); setTimeout(() => { TestUtils.gc(); pending = 0; }, 0);");
    try settle(browser);
    try check(browser);
}

const document_parts = [_][]const u8{ "HTMLHtmlElement", "HTMLHeadElement", "HTMLBodyElement", "HTMLElement" };

fn navigatedFrames() !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try openPage(browser);
    const first = count(browser, &document_parts);
    try testing.expect(first >= 3);
    for (1..4) |page| {
        try openPage(browser);
        const now = count(browser, &document_parts);
        if (now != first) {
            std.debug.print("page {d}: the old documents' html/head/body stayed: {d} -> {d}\n", .{ page + 1, first, now });
            return error.PageStorageRetained;
        }
    }
}

test "a navigated frame's old documents give back their slots once their realm retired" {
    try helpers.onFreshThread(navigatedFrames);
}

fn heldNodeOfOldDocument() !void {
    // The parent keeps a node of the frame's first document across both
    // navigations: it keeps its slot, and reads as a node of a document that
    // is no longer active - its text, its document, still itself. Meanwhile
    // impostors of the second document's types, each announcing itself, are
    // made between the slices that free the second document - into every
    // slot those slices give back - and must stay untouched.
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    for (0..3) |_| {
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        try page.runScript(navigate_twice);
        try settle(browser);
        try page.runScript(
            \\globalThis.impostors = [];
            \\globalThis.pending = 1;
            \\let rounds = 0;
            \\(function churn() {
            \\  for (let i = 0; i < 100; ++i) {
            \\    const n = document.createElement('i');
            \\    n.textContent = 'impostor';
            \\    n.setAttribute('data-impostor', impostors.length);
            \\    impostors.push(n, document.createElement('html'), document.createElement('head'), document.createElement('body'));
            \\  }
            \\  TestUtils.gc();
            \\  if (++rounds < 20) return setTimeout(churn, 0);
            \\  if (kept.textContent !== 'one') failed = 'the kept node reads ' + kept.textContent;
            \\  if (kept.localName !== 'p') failed = 'the kept node is a ' + kept.localName;
            \\  if (kept.ownerDocument === document) failed = 'the kept node moved documents';
            \\  if (kept.ownerDocument.body.textContent !== 'one') failed = 'its document reads ' + kept.ownerDocument.body.textContent;
            \\  impostors.forEach((n, i) => {
            \\    if (i % 4 === 0 && (n.textContent !== 'impostor' || n.getAttribute('data-impostor') !== String(i))) failed = 'an impostor was touched: ' + i;
            \\    if (n.parentNode !== null || n.firstChild && i % 4 !== 0) failed = 'an impostor was changed: ' + i;
            \\  });
            \\  pending = 0;
            \\})();
        );
        try settle(browser);
        try check(browser);
    }
}

test "a node of a navigated frame's old document the parent holds keeps its slot and reads safely" {
    try helpers.onFreshThread(heldNodeOfOldDocument);
}

/// The WPT shape that does keep them (initial-empty-document/iframe-nosrc,
/// srcdoc-history-entries): a frame on its initial empty document, its
/// window read, navigated away twice through its src - each navigation
/// retiring a realm whose document the deferred teardown queue frees later.
const navigate_from_initial_empty =
    \\globalThis.pending = 1;
    \\const f = document.body.appendChild(document.createElement('iframe'));
    \\void f.contentWindow.document.title;
    \\let loads = 0;
    \\f.onload = () => {
    \\  void f.contentWindow.location.href;
    \\  if (++loads === 1) f.src = 'about:blank?2';
    \\  else { f.remove(); pending = 0; }
    \\};
    \\f.src = 'about:blank?1';
;

fn initialEmptyNavigated() !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var first: usize = 0;
    for (0..4) |page_index| {
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        try page.runScript(navigate_from_initial_empty);
        try settle(browser);
        try page.runScript("globalThis.pending = 1; TestUtils.gc(); TestUtils.gc(); setTimeout(() => { TestUtils.gc(); pending = 0; }, 0);");
        try settle(browser);
        try check(browser);
        const now = count(browser, &document_parts);
        if (page_index == 0) {
            first = now;
        } else if (now != first) {
            std.debug.print("page {d}: the retired realms' html/head/body stayed: {d} -> {d}\n", .{ page_index + 1, first, now });
            return error.PageStorageRetained;
        }
    }
}

test "a frame navigated away from its initial empty document gives back its old documents' slots" {
    try helpers.onFreshThread(initialEmptyNavigated);
}
