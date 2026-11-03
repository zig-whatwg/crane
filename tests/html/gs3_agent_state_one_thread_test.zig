//! Two Browsers on ONE thread - two agents, each with its own event loop -
//! keep their agent's and their realms' state apart (lane gstate3,
//! docs/instances.md "The model": state has an owner - the process, a
//! Browser, a tab, an agent or a realm - never a thread).
//!
//! - A Window's map of active timers is its realm's (HTML 8.6: "each object
//!   that implements WindowOrWorkerGlobalScope has a map of active timers"),
//!   and its timers run on its own agent's event loop. They were one map and
//!   one "current timer interface" per thread, set by whichever Browser made a
//!   realm last: Browser A's setTimeout armed a timer on Browser B's loop, and
//!   B's page end cleared A's timers with its own.
//! - The mutation observer microtask queued flag and the pending mutation
//!   observers are the similar-origin window agent's (DOM 4.3 "Each
//!   similar-origin window agent has a mutation observer microtask queued ...
//!   pending mutation observers"). They were per thread: A's queued microtask
//!   kept B from queueing its own, and B's page end dropped A's pending
//!   observers.
//!
//! Each test runs on a thread of its own, so it starts from a fresh thread's
//! state whatever ran before it in the process.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

/// Show a fresh page (no network: its markup is given) - a new Context, so
/// the Browser's previous page, if any, ends first.
fn openPage(browser: *browser_mod.Browser, url: []const u8) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=root></div></body>", .{ .base_url = url });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

/// Turn `browser`'s event loop - and only its - until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

fn timerRunsOnItsOwnAgentsLoop() !void {
    const a = try startBrowser();
    defer a.deinit();
    try openPage(a, "http://gs3-a.test/page.html");
    // B's page is made after A's: its realm was the thread's last.
    const b = try startBrowser();
    defer b.deinit();
    try openPage(b, "http://gs3-b.test/page.html");

    try expectScript(a, "globalThis.fired = false; setTimeout(() => { globalThis.fired = true; }, 0) > 0");
    // Only A's loop turns: A's timer is A's agent's.
    try waitFor(a, "globalThis.fired === true");
}

test "a Window's timer runs on its own agent's event loop, not on the loop of the Browser whose realm was made last" {
    try onFreshThread(timerRunsOnItsOwnAgentsLoop);
}

fn pageEndLeavesOtherBrowsersTimers() !void {
    const a = try startBrowser();
    defer a.deinit();
    try openPage(a, "http://gs3-a.test/page.html");
    const b = try startBrowser();
    defer b.deinit();
    try openPage(b, "http://gs3-b.test/page.html");

    try expectScript(a, "globalThis.fired = false; globalThis.armed = setTimeout(() => { globalThis.fired = true; }, 30); armed > 0");
    // B's page ends (a new page replaces it): its realm's timers go, and
    // only its.
    try openPage(b, "http://gs3-b.test/next.html");
    try expectScript(a, "globalThis.later = false; setTimeout(() => { globalThis.later = true; }, 0) > 0");
    try waitFor(a, "globalThis.fired === true && globalThis.later === true");
}

test "a Browser's page end clears its own realm's timers and leaves another Browser's on the same thread alone" {
    try onFreshThread(pageEndLeavesOtherBrowsersTimers);
}

/// Change the root element's `data-x` from native code: a mutation that
/// runs no script, so no microtask checkpoint follows it - the mutation
/// observer microtask it queues waits in its agent's queue.
fn mutateWithoutScript(browser: *browser_mod.Browser, value: []const u8) !void {
    const document = browser.current_context.?.document_instance orelse return error.NoDocument;
    const root = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("root"))) orelse return error.NoRoot;
    try interfaces.Element.call_setAttribute(root, runtime.DOMString.initInterned("data-x"), .{ .domstring = runtime.DOMString.initInterned(value) });
}

const observe_root =
    \\globalThis.seen = 0;
    \\globalThis.mo = new MutationObserver((records) => { globalThis.seen += records.length; });
    \\mo.observe(document.getElementById("root"), { attributes: true });
    \\true
;

fn observerMicrotaskIsEachAgents() !void {
    const a = try startBrowser();
    defer a.deinit();
    try openPage(a, "http://gs3-a.test/page.html");
    const b = try startBrowser();
    defer b.deinit();
    try openPage(b, "http://gs3-b.test/page.html");

    try expectScript(a, observe_root);
    try expectScript(b, observe_root);
    // A's mutation queues A's agent's mutation observer microtask, which
    // has not run yet: A has had no checkpoint since.
    try mutateWithoutScript(a, "1");
    // B's own mutation queues B's agent's microtask, which B's checkpoint
    // at the end of this script runs - notifying B's observer, and only it.
    try expectScript(b, "document.getElementById('root').setAttribute('data-x', '2'); true");
    try expectScript(b, "globalThis.seen === 1");
    // A's microtask runs at A's next checkpoint (the end of the first
    // script), and its observer then has its one record.
    try expectScript(a, "true");
    try expectScript(a, "globalThis.seen === 1");
}

test "the mutation observer microtask is each agent's: one queued in another agent on the thread does not hold back this agent's" {
    try onFreshThread(observerMicrotaskIsEachAgents);
}

fn pageEndKeepsOtherAgentsObservers() !void {
    const a = try startBrowser();
    defer a.deinit();
    try openPage(a, "http://gs3-a.test/page.html");
    const b = try startBrowser();
    defer b.deinit();
    try openPage(b, "http://gs3-b.test/page.html");

    try expectScript(a, observe_root);
    try mutateWithoutScript(a, "1");
    // B's page ends while A's observer is pending in A's agent.
    try openPage(b, "http://gs3-b.test/next.html");
    try expectScript(a, "true");
    try expectScript(a, "globalThis.seen === 1");
}

test "a Browser's page end leaves another agent's pending mutation observers on the same thread alone" {
    try onFreshThread(pageEndKeepsOtherAgentsObservers);
}
