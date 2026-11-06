//! The many-Browsers variant's busy Browser: the work the neighbour
//! (neighbour.zig) runs beside every test, one Browser per iteration.
//!
//! Each iteration makes a Browser with an allocator of its own - a leak-
//! checking DebugAllocator that poisons what it frees (poisoning.zig), never
//! the shared std.testing.allocator, whose lock would make the two Browsers
//! take turns (docs/lessons/testing-a-shared-test-allocator-makes-two-
//! browsers-take-turns.md) - and loads two
//! pages in it, each a navigation and a parse with scripts: DOM churn (nodes
//! made, moved, removed, a live range emptying a subtree, a MutationObserver
//! watching it all), timers (a setInterval nesting to its clamp, a timeout),
//! microtasks, event dispatch, a form's data, a window message and a second
//! parser. After each page's event loop has run its work out, a check script
//! reads what the work left, so a page that did not do it fails the
//! iteration. Then the Browser ends and the allocator is checked for leaks.
//!
//! So while a test runs, another thread of its process is starting and
//! ending isolates and realms, running the event loop and the parser,
//! allocating and collecting - real Browser work on whatever the two
//! Browsers share: process-wide state, the engine's process-wide parts, the
//! platform.

const std = @import("std");
const Io = std.Io;
const suite = @import("suite.zig");
const poisoning = @import("poisoning.zig");

/// The first page: DOM churn, timers and microtasks.
const churn_page =
    \\<!doctype html><title>busy Browser</title><body><div id=root></div>
    \\<script>
    \\window.__done = 0; window.__mutations = 0;
    \\const root = document.getElementById('root');
    \\new MutationObserver(records => { window.__mutations += records.length; })
    \\  .observe(root, { childList: true, subtree: true, attributes: true, characterData: true });
    \\for (let i = 0; i < 300; i++) {
    \\  const el = root.appendChild(document.createElement(i % 2 ? 'span' : 'p'));
    \\  el.setAttribute('data-i', String(i));
    \\  el.textContent = 'busy ' + i;
    \\  if (i % 3 === 0) el.remove();
    \\}
    \\root.insertAdjacentHTML('beforeend', '<ul>' + '<li class=item>x</li>'.repeat(100) + '</ul>');
    \\Array.from(document.querySelectorAll('li.item')).forEach((li, i) => { if (i % 2) li.remove(); });
    \\const range = document.createRange();
    \\range.selectNodeContents(root);
    \\range.deleteContents();
    \\let ticks = 0;
    \\const interval = setInterval(() => {
    \\  root.appendChild(document.createTextNode('t' + ticks));
    \\  if (++ticks === 6) {
    \\    clearInterval(interval);
    \\    Promise.resolve().then(() => { root.textContent = ''; window.__done++; });
    \\  }
    \\}, 0);
    \\setTimeout(() => { window.__done++; }, 1);
    \\queueMicrotask(() => { document.body.dataset.micro = 'ran'; });
    \\</script>
;
const churn_check = "String(window.__done) + ':' + (window.__mutations > 0) + ':' + document.body.dataset.micro + ':' + document.getElementById('root').childNodes.length";
const churn_want = "2:true:ran:0";

/// The second page: events, a form, a window message, a second parser.
const events_page =
    \\<!doctype html><title>busy Browser</title>
    \\<form><input name=a value=1><select name=s><option>x<option selected>y</select></form>
    \\<script>
    \\window.__events = 0;
    \\const target = new EventTarget();
    \\target.addEventListener('ping', () => window.__events++);
    \\for (let i = 0; i < 100; i++) target.dispatchEvent(new Event('ping'));
    \\const data = new FormData(document.forms[0]);
    \\window.__form = data.get('a') + data.get('s');
    \\window.addEventListener('message', e => { window.__message = e.data.n + e.data.list.length; });
    \\window.postMessage({ n: 40, list: [1, 2] }, '*');
    \\window.__parsed = new DOMParser().parseFromString('<p>a<b>b</b></p>', 'text/html').body.textContent;
    \\</script>
;
const events_check = "window.__events + ':' + window.__form + ':' + window.__message + ':' + window.__parsed";
const events_want = "100:1y:42:ab";

const Page = struct { html: []const u8, check: []const u8, want: []const u8 };
const pages = [_]Page{
    .{ .html = churn_page, .check = churn_check, .want = churn_want },
    .{ .html = events_page, .check = events_check, .want = events_want },
};

/// One iteration (neighbour.Work.iterate).
pub fn iterate(_: ?*anyopaque, why: *Io.Writer) anyerror!void {
    if (suite.browser) |browser_mod| return iterateWith(browser_mod, why);
    return error.NoBrowserInThisExecutable;
}

fn iterateWith(comptime browser_mod: type, why: *Io.Writer) anyerror!void {
    var debug_allocator: poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    {
        errdefer _ = debug_allocator.deinit();
        try runPages(browser_mod, debug_allocator.allocator(), why);
    }
    if (debug_allocator.deinit() == .leak) {
        why.writeAll("the busy Browser's allocator reported a leak") catch {};
        return error.BusyBrowserLeaked;
    }
}

fn runPages(comptime browser_mod: type, allocator: std.mem.Allocator, why: *Io.Writer) !void {
    // No snapshot: one found from the working directory may be another
    // build's (the tests/v8 snapshot lesson); a fresh isolate is real work.
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    for (pages, 0..) |page_spec, i| {
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        page.loadHTML(page_spec.html, .{ .base_url = "about:blank" }) catch |err| {
            why.print("page {d}: loadHTML failed: {t}", .{ i, err }) catch {};
            return err;
        };
        // Until the page's timers and tasks have run out (the loop returns
        // early once nothing is pending).
        _ = try browser.runEventLoopBlocking(2000);
        const got = page.evaluateScriptToString(page_spec.check, allocator) catch |err| {
            why.print("page {d}: the check script failed: {t}", .{ i, err }) catch {};
            return err;
        };
        defer allocator.free(got);
        if (!std.mem.eql(u8, got, page_spec.want)) {
            why.print("page {d}: the page's work left \"{s}\", expected \"{s}\"", .{ i, got, page_spec.want }) catch {};
            return error.BusyBrowserWorkWrong;
        }
    }
}
