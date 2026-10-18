//! Two Browsers on two threads (lane bfcache-a): one makes frames, queues
//! tasks and timers to them and takes them away - removed, navigated, or
//! replaced by a load before they loaded - so their documents stop being
//! fully active while their tasks are queued; the other runs 10,000 tasks and
//! timers at the same time. Each window event loop classifies its own
//! tasks' documents through the one dom.document_activity hook, written
//! once at process start, and keeps its own waiting tasks: neither Browser's
//! tasks run, wait or drop by the other's documents, every task of a gone
//! document is dropped without running, and nothing leaks.
//!
//! Each Browser allocates from a DebugAllocator of its own, without stack
//! traces (std.testing.allocator's one lock would make the two take turns;
//! docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md),
//! which still fails the test on a leak.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://bfa-two.test/page.html";
const rounds = 6;

fn startBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 2000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn loadPage(browser: *browser_mod.Browser, html: []const u8) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(html, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
}

/// Frames that go: each round makes three frames and waits for their
/// documents (`frames_made`), then gives each a message and a timer (whose
/// listeners count in the page), and removes one, navigates one and keeps
/// one (`churn_round`). The kept frame's message and timer arrive, the
/// removed one's never do; the navigated one's may arrive before the
/// navigation commits, and are not counted.
/// The page is new each round (loaded again at the round's end).
const make_frames =
    \\(() => {
    \\  globalThis.bfaFrames = ["removed", "navigated", "kept"].map(kind => {
    \\    const f = document.createElement("iframe");
    \\    f.srcdoc = "<p>" + kind;
    \\    document.body.append(f);
    \\    return f;
    \\  });
    \\  return true;
    \\})()
;

const frames_made =
    \\bfaFrames.every((f, i) => f.contentDocument?.readyState === "complete" &&
    \\  f.contentDocument.body?.textContent === ["removed", "navigated", "kept"][i])
;

const churn_round =
    \\(() => {
    \\  globalThis.bfaHeard = { kept: 0, gone: 0, moved: 0 };
    \\  const [removed, navigated, kept] = bfaFrames;
    \\  for (const f of bfaFrames) {
    \\    const slot = f === kept ? "kept" : f === removed ? "gone" : "moved";
    \\    const w = f.contentWindow;
    \\    w.addEventListener("message", () => bfaHeard[slot]++);
    \\    w.setTimeout(() => bfaHeard[slot]++, 0);
    \\    w.postMessage("bfa", "*");
    \\  }
    \\  removed.remove();
    \\  navigated.srcdoc = "<p>elsewhere";
    \\  return true;
    \\})()
;

/// 10,000 messages to the page itself and 1,000 timers, counted in order.
const busy_round =
    \\(() => {
    \\  globalThis.bfaBusy = { next: 0, bad: 0, timers: 0 };
    \\  onmessage = (e) => { if (e.data !== bfaBusy.next++) bfaBusy.bad++; };
    \\  for (let i = 0; i < 10000; i++) postMessage(i, "*");
    \\  for (let i = 0; i < 1000; i++) setTimeout(() => bfaBusy.timers++, 0);
    \\  return true;
    \\})()
;

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 50_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Role = enum { churn, busy };

const Side = struct {
    shared: *Shared,
    role: Role,
    failure: ?anyerror = null,
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try startBrowser(self.debug_allocator.allocator());
        defer browser.deinit();
        try loadPage(browser, "<!doctype html><body><p>page</p></body>");
        for (0..rounds) |round| {
            try self.shared.meet(@intCast(round + 1));
            switch (self.role) {
                .churn => {
                    if (!try truthy(browser, make_frames)) return error.RoundFailed;
                    try waitFor(browser, frames_made);
                    if (!try truthy(browser, churn_round)) return error.RoundFailed;
                    try waitFor(browser, "bfaHeard.kept === 2");
                    // Nothing queued to a frame that went ever ran.
                    if (!try truthy(browser, "bfaHeard.gone === 0")) return error.AGoneFrameTaskRan;
                    // A load replacing a document before it loaded: that
                    // document is gone at once (its window lets go of it),
                    // and its own tasks (its load event's) are dropped.
                    const context = browser.current_context orelse return error.NoPage;
                    try context.loadHTML("<!doctype html><body><p>replaced before it loaded</p></body>", .{ .base_url = page_url });
                    try context.loadHTML("<!doctype html><body><p>page</p></body>", .{ .base_url = page_url });
                    try waitFor(browser, "document.readyState === 'complete'");
                },
                .busy => {
                    if (!try truthy(browser, busy_round)) return error.RoundFailed;
                    try waitFor(browser, "bfaBusy.next === 10000 && bfaBusy.timers === 1000");
                    if (!try truthy(browser, "bfaBusy.bad === 0")) return error.OutOfOrder;
                },
            }
        }
        // Whatever still waits goes with the loop.
        _ = try browser.runEventLoopBlocking(20);
    }
};

test "one Browser's frames stop being fully active while another runs 10,000 tasks, on two threads" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared, .role = .churn }, .{ .shared = &shared, .role = .busy } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
