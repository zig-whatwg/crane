//! Lane refcount9 (refcount step 7a; the integrator's ruling (c), gated): a
//! Document's lifecycle tasks - DOMContentLoaded, the load task that makes it
//! "complete" (readystatechange), a declarative refresh, script delivery -
//! hold it counted from queueing to their run or drop (refcount8,
//! H-RC8-DOC-LIFECYCLE). When the Document's own count reaches zero with no
//! window, nothing can reach it any more (no wrapper; a held node keeps its
//! document's wrapper, so its count), so with no listener on it the events
//! those tasks would fire are unobservable: the tasks are dropped - their
//! holds released - and the document goes by the ordinary rules, without
//! waiting for the event loop. WebKit's Document::removedLastRef stops the
//! document's pending work the same way. A listener, or a node held, keeps
//! the tasks.
//!
//! Each case runs ONE script that makes the documents, so no task can run
//! before the native collections that follow it.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
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

const Page = struct {
    browser: *browser_mod.Browser,

    fn open() !Page {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        _ = try browser.runEventLoopBlocking(20);
        try collect(browser);
        return .{ .browser = browser };
    }

    fn close(self: Page) void {
        self.browser.deinit();
    }

    fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        try page.runScript(source);
    }

    fn live(self: Page) usize {
        return self.browser.scope.slab.stats().currently_allocated;
    }

    fn expectTrue(self: Page, source: []const u8) !void {
        const held = try self.browser.evaluateScript(source);
        defer held.release();
        const realm = self.browser.getRealm() orelse return error.NoRealm;
        if (!engine.toBoolean(realm, held.borrow())) {
            std.debug.print("expected true: {s}\n", .{source});
            return error.TestExpectedTrue;
        }
    }
};

/// Two full collections from native code, outside any script: the deferred
/// teardown queue drains after each (no event loop turn, so no task runs).
fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

const make_documents =
    \\for (let i = 0; i < 200; i++) {
    \\  const d = document.implementation.createHTMLDocument('');
    \\  d.open(); d.write('<div><p>one</p><p>two</p></div>'); d.close();
    \\}
;

fn unobservedDocumentsGoWithoutTheirTasks() !void {
    const page = try Page.open();
    defer page.close();
    const before = page.live();
    try page.run(make_documents);
    try collect(page.browser);
    // Every document dropped, none listened to: its pending lifecycle tasks
    // were dropped with its last reference, and the documents freed - no
    // event loop turn ran them.
    const grown = page.live() -| before;
    if (grown > 64) std.debug.print("200 dropped documents: {d} instances still alive before any turn\n", .{grown});
    try testing.expect(grown <= 64);
    _ = try page.browser.runEventLoopBlocking(20);
}

test "documents nothing reaches or listens to are freed without waiting for their lifecycle tasks" {
    try onFreshThread(unobservedDocumentsGoWithoutTheirTasks);
}

fn aListenedDocumentKeepsItsTasks() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.fired = 0;
        \\{
        \\  const d = document.implementation.createHTMLDocument('');
        \\  d.open();
        \\  // After open(): document.open() erases every listener and handler.
        \\  d.addEventListener('DOMContentLoaded', () => { globalThis.fired++; });
        \\  d.write('<p>listened</p>'); d.close();
        \\}
    );
    try collect(page.browser);
    _ = try page.browser.runEventLoopBlocking(20);
    try page.expectTrue("globalThis.fired === 1");
}

test "a dropped document with a DOMContentLoaded listener still fires it" {
    try onFreshThread(aListenedDocumentKeepsItsTasks);
}

fn aHeldNodeKeepsItsDocumentsTasks() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\{
        \\  const d = document.implementation.createHTMLDocument('');
        \\  d.open(); d.write('<p id=held>held</p>'); d.close();
        \\  globalThis.held = d.getElementById('held');
        \\}
    );
    try collect(page.browser);
    _ = try page.browser.runEventLoopBlocking(20);
    // Its load task ran: the document a held node keeps finished loading.
    try page.expectTrue("held.ownerDocument.readyState === 'complete'");
    try page.run("globalThis.held = null;");
}

test "a document a held node keeps runs its lifecycle tasks" {
    try onFreshThread(aHeldNodeKeepsItsDocumentsTasks);
}

/// The load arm ("the end" steps 7-9, nav2's re-check that may queue the
/// load anew - H-NAV2-DOC-LOAD-RECHECK): a windowless document's load is
/// delayed by nothing (it loads no frame and runs no script), so its load
/// task is the one d.close() queued. Observed through readystatechange, it
/// runs and the document completes; unobserved, case 1 drops it with the
/// others. A re-queued load task is a new task in the same list.
fn aListenedLoadCompletes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.states = [];
        \\{
        \\  const d = document.implementation.createHTMLDocument('');
        \\  d.open();
        \\  d.onreadystatechange = () => globalThis.states.push(d.readyState);
        \\  d.write('<p>load</p>'); d.close();
        \\}
    );
    try collect(page.browser);
    _ = try page.browser.runEventLoopBlocking(20);
    try page.expectTrue("globalThis.states.includes('complete')");
}

test "a dropped document whose readystatechange is observed still completes its load" {
    try onFreshThread(aListenedLoadCompletes);
}

/// One script making and dropping documents whose lifecycle tasks are still
/// queued: the item that detaches each one weighs its tree, so the deferred
/// teardown queue's memory bound sees them, and past high_water (100,000
/// queued nodes) the next binding exit back into script relieves - detach,
/// drop, free - inside the script (refcount design 9 risk 4's depth; the
/// parser-write cost row). Measured: 109,140 slots grown; with the item
/// weighing nothing, 425,850 - every document of the script. The script also makes JS garbage, as any page's
/// does, so the engine's own collections run inside it: a dropped
/// document's wrapper dies in one, and its second pass - the deref - runs at
/// the start of the next (V8 13.1 heap.cc: the GC prologue "ensure[s] that
/// all pending phantom callbacks are invoked"). Without that garbage the
/// script triggers no collection, every wrapper lives to its end, and no
/// teardown could run inside it. The slab never returns a slab, so its
/// capacity growth is the run's peak of live instances: bounded near
/// high_water, not by the 600 documents x ~700 nodes the script makes.
fn droppedDocumentsInOneScriptStayBounded() !void {
    const page = try Page.open();
    defer page.close();
    const before = page.browser.scope.slab.stats().total_capacity;
    try page.run(
        \\{
        \\  const markup = '<div><p>a</p><p>b</p><p>c</p></div>'.repeat(100);
        \\  let junk = null;
        \\  for (let i = 0; i < 600; i++) {
        \\    const d = document.implementation.createHTMLDocument('');
        \\    d.open(); d.write(markup); d.close();
        \\    for (let k = 0; k < 64; k++) junk = new Array(1024).fill(k);
        \\  }
        \\}
    );
    const grown = page.browser.scope.slab.stats().total_capacity -| before;
    if (grown >= 300_000) std.debug.print("600 dropped documents in one script: the slab grew by {d} slots\n", .{grown});
    try testing.expect(grown < 300_000);
    try collect(page.browser);
    _ = try page.browser.runEventLoopBlocking(20);
}

test "documents dropped inside one script stay bounded by the queue's high water, not by their number" {
    try onFreshThread(droppedDocumentsInOneScriptStayBounded);
}
