//! Lane abortsig1: an ended page's AbortSignals give their slots back.
//!
//! testharness.js makes an AbortController per test (Test's
//! `_abortController`, aborted by its cleanup) and never reads its signal,
//! so the signal is never wrapped. The controller owns such a signal and
//! tears it down with itself (AbortController.InternalState.deinit) - by its
//! interface's destructor chain alone, which released the signal's state but
//! never its slab slot or state block (runtime.gc.releaseStorage). Nothing
//! else would ever free them: no wrapper owned the signal. So one slot per
//! subtest stayed with the Browser until it ended - 14,463 after ten dom/
//! files in one runner process - and `leaks --atExit` saw nothing, because
//! the Browser's end freed the slab.
//!
//! Each test churns pages in one Browser and requires the AbortSignal and
//! AbortController slots after every page to be the first page's: a page's
//! count must not include the pages before it. Signals of every making -
//! a controller's, AbortSignal.any's, timeout()'s (fired and pending at the
//! page's end), abort()'s, a Request's and a fetch's - and of every use -
//! never read, read and dropped, listened to, an addEventListener `signal`
//! option, a fetch, a pipe still running at the page's end, a frame's
//! dependents of the page's signals.
//!
//! The Browser runs on std.testing.allocator, so whatever is freed must be
//! freed exactly once, and each test runs on a thread of its own (tests/html
//! is one executable; a Browser's agent belongs to the thread that made it).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const Counts = struct {
    signals: usize = 0,
    controllers: usize = 0,
};

/// Live slab slots of AbortSignal and AbortController, by their vtables'
/// names - read from the slab, so an object whose teardown ran but whose
/// slot was never returned still counts.
fn countsOf(browser: *browser_mod.Browser) Counts {
    var counts: Counts = .{};
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            const name = instance.vtable.name;
            if (std.mem.eql(u8, name, "AbortSignal")) counts.signals += 1;
            if (std.mem.eql(u8, name, "AbortController")) counts.controllers += 1;
        }
    }
    return counts;
}

/// Navigate (ending the page before, if any), load an empty body, run
/// `script` in the new page, let its tasks run and collect what it let go
/// of, so the counts are the page's own.
fn openPage(browser: *browser_mod.Browser, script: []const u8) !void {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    page.runScript(script) catch |err| {
        std.debug.print("script failed: {s}\n", .{script});
        return err;
    };
    _ = try browser.runEventLoopBlocking(50);
    try page.runScript("TestUtils.gc(); TestUtils.gc();");
    _ = try browser.runEventLoopBlocking(20);
    // The script's own check, made after its tasks ran: `globalThis.failed`
    // names what went wrong.
    const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
    defer testing.allocator.free(failed);
    if (failed.len != 0) {
        std.debug.print("page check failed: {s}\n", .{failed});
        return error.PageCheckFailed;
    }
}

/// Open `pages` pages running `script` each, and require each page's
/// AbortSignal and AbortController slots to be the first page's. The first
/// page must hold at least `own_signals` signals of its own, so a script
/// that made none cannot pass.
fn churn(script: []const u8, pages: usize, own_signals: usize) !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();

    try openPage(browser, script);
    const first = countsOf(browser);
    try testing.expect(first.signals >= own_signals);
    for (1..pages) |page| {
        try openPage(browser, script);
        const now = countsOf(browser);
        if (now.signals != first.signals or now.controllers != first.controllers) {
            std.debug.print("page {d}: an ended page's abort objects stayed: first page {any}, now {any}\n", .{ page + 1, first, now });
            return error.PageStorageRetained;
        }
    }
}

fn testharnessShape() !void {
    // testharness.js's shape: a controller per test, kept by script until
    // the page ends, aborted at cleanup, its signal never read.
    try churn(
        \\globalThis.kept = [];
        \\for (let i = 0; i < 200; ++i) { const c = new AbortController(); kept.push(c); c.abort('Test cleanup'); }
        \\for (let i = 0; i < 50; ++i) kept.push(new AbortController());
    , 4, 250);
}

test "a page's never-read controller signals give back their slots when its realm ends" {
    try helpers.onFreshThread(testharnessShape);
}

fn collectedInPage() !void {
    // Controllers script drops while the page lives: the collector frees
    // each, and with it the signal it owns. Nothing is left for the
    // realm's end, so a leaked signal shows on the first page too - the
    // page keeps 10 to be measured against.
    try churn(
        \\for (let i = 0; i < 300; ++i) { const c = new AbortController(); if (i % 2) c.abort(); }
        \\TestUtils.gc(); TestUtils.gc();
        \\globalThis.kept = [];
        \\for (let i = 0; i < 10; ++i) kept.push(new AbortController());
    , 4, 10);
}

test "controllers collected while their page lives free their never-read signals" {
    try helpers.onFreshThread(collectedInPage);
}

fn handedOut() !void {
    // Signals script reads: wrapped, so their wrappers own them - listened
    // to, an `onabort` handler, an addEventListener `signal` option, kept
    // without their controllers and dropped with them.
    try churn(
        \\globalThis.kept = [];
        \\globalThis.heard = 0;
        \\const target = document.body;
        \\for (let i = 0; i < 100; ++i) {
        \\  const c = new AbortController();
        \\  c.signal.addEventListener('abort', () => { ++heard; });
        \\  c.signal.onabort = () => {};
        \\  target.addEventListener('click', () => {}, { signal: c.signal });
        \\  if (i % 3 === 0) kept.push(c.signal); else if (i % 3 === 1) kept.push(c);
        \\  if (i % 2) c.abort(new Error('reason ' + i));
        \\}
        \\if (heard !== 50) globalThis.failed = 'heard ' + heard;
    , 4, 34);
}

test "a page's read, listened-to and listener-option signals give back their slots" {
    try helpers.onFreshThread(handedOut);
}

fn dependents() !void {
    // AbortSignal.any: dependents of plain and of dependent signals, made
    // from aborted and live sources, kept and dropped - the source and
    // dependent sets hold each other weakly.
    try churn(
        \\globalThis.kept = [];
        \\for (let i = 0; i < 50; ++i) {
        \\  const a = new AbortController(), b = new AbortController();
        \\  const any = AbortSignal.any([a.signal, b.signal]);
        \\  const anyOfAny = AbortSignal.any([any, AbortSignal.any([b.signal])]);
        \\  if (i % 2) a.abort('a');
        \\  if (i % 5 === 0) kept.push(anyOfAny); else if (i % 5 === 1) kept.push(a, b); else if (i % 5 === 2) kept.push(any);
        \\  if (i % 2 && !anyOfAny.aborted) globalThis.failed = 'dependent not aborted';
        \\  AbortSignal.any([AbortSignal.abort('x'), a.signal]);
        \\}
    , 4, 10);
}

test "a page's AbortSignal.any dependents and their sources give back their slots" {
    try helpers.onFreshThread(dependents);
}

fn timeouts() !void {
    // AbortSignal.timeout: fired (its timer's steps held it until they
    // ran), and pending at the page's end, held by its pending activity -
    // the realm's end must cancel the timer and free it.
    try churn(
        \\globalThis.kept = [];
        \\globalThis.timedOut = 0;
        \\for (let i = 0; i < 20; ++i) AbortSignal.timeout(0).onabort = () => { ++timedOut; };
        \\for (let i = 0; i < 20; ++i) AbortSignal.timeout(1000000);
        \\for (let i = 0; i < 5; ++i) kept.push(AbortSignal.timeout(1000000));
        \\for (let i = 0; i < 20; ++i) AbortSignal.abort('x');
        \\setTimeout(() => { if (timedOut !== 20) globalThis.failed = 'timed out ' + timedOut; }, 20);
    , 4, 25);
}

test "a page's timeout signals, fired and pending at its end, give back their slots" {
    try helpers.onFreshThread(timeouts);
}

fn fetches() !void {
    // A Request's signal (a dependent of the init's signal, or of none) and
    // a fetch()'s, finished and aborted before it started, and one whose
    // controller outlives it to the page's end.
    try churn(
        \\globalThis.kept = [];
        \\globalThis.settled = 0;
        \\for (let i = 0; i < 20; ++i) {
        \\  const c = new AbortController();
        \\  const r = new Request('data:text/plain,x', { signal: c.signal });
        \\  if (i % 2) kept.push(r); else void r.signal.aborted;
        \\  new Request('data:text/plain,y');
        \\  fetch('data:text/plain,z', { signal: c.signal }).then(() => ++settled, () => ++settled);
        \\  fetch('data:text/plain,z', { signal: AbortSignal.abort() }).catch(() => ++settled);
        \\}
        \\const late = new AbortController();
        \\kept.push(late);
        \\fetch('data:text/plain,w', { signal: late.signal });
        \\setTimeout(() => { if (settled !== 40) globalThis.failed = 'settled ' + settled; }, 30);
    , 4, 11);
}

test "a page's Request and fetch signals give back their slots" {
    try helpers.onFreshThread(fetches);
}

fn pipes() !void {
    // pipeTo's signal: its abort algorithm holds the pipe; a pipe still
    // running when the page ends (a source that never closes), one aborted,
    // one finished.
    try churn(
        \\globalThis.kept = [];
        \\for (let i = 0; i < 10; ++i) {
        \\  const c = new AbortController();
        \\  const open = new ReadableStream({ pull() {} });
        \\  open.pipeTo(new WritableStream(), { signal: c.signal }).catch(() => {});
        \\  if (i % 2) c.abort(); else kept.push(c);
        \\  const done = new ReadableStream({ start(k) { k.enqueue(1); k.close(); } });
        \\  done.pipeTo(new WritableStream(), { signal: new AbortController().signal });
        \\}
    , 4, 5);
}

test "a page's pipeTo signals, running and aborted at its end, give back their slots" {
    try helpers.onFreshThread(pipes);
}

fn crossRealm() !void {
    // A frame's dependents of the page's signals and the page's of the
    // frame's: a frame removed in the page (its realm ends first, at a
    // task) and one that ends with the page.
    try churn(
        \\globalThis.kept = [];
        \\const frames = [document.createElement('iframe'), document.createElement('iframe')];
        \\for (const f of frames) document.body.appendChild(f);
        \\for (const f of frames) {
        \\  const w = f.contentWindow;
        \\  const here = new AbortController();
        \\  const there = new w.AbortController();
        \\  kept.push(here, AbortSignal.any([there.signal, here.signal]));
        \\  w.kept = [w.AbortSignal.any([here.signal]), there];
        \\  w.AbortSignal.any([here.signal, AbortSignal.timeout(1000000)]);
        \\}
        \\frames[0].remove();
        \\kept[0].abort('after removal');
        \\if (!kept[1].aborted) globalThis.failed = 'cross-realm dependent not aborted';
    , 4, 4);
}

test "a page's cross-realm AbortSignal.any dependents give back their slots" {
    try helpers.onFreshThread(crossRealm);
}
