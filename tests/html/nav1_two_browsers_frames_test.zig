//! Two Browsers on two threads make, navigate and remove frames at the same
//! time (lane nav1): a frame's load event order (the container's load inside
//! the child's window load, before its pageshow), a srcdoc frame's origin
//! (its container document's origin record), a fragment navigation's
//! :target, and a traversal's active entry are each Browser's own state -
//! documents, origin records, joint histories - and the hook tables they are
//! reached through are written once at process start, so neither Browser's
//! answers see the other's frames and neither frees what the other reads.
//!
//! Each Browser allocates from a DebugAllocator of its own, without stack
//! traces (std.testing.allocator's one lock would make the two take turns;
//! docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md),
//! which still fails the test on a leak.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page = "<!doctype html><body></body>";
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

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

/// A srcdoc frame that reports its window's load and pageshow, and its
/// container's load, into `nav1.log`.
const start_script =
    \\(() => {
    \\  globalThis.nav1 = { log: [] };
    \\  const f = document.createElement("iframe");
    \\  nav1.frame = f;
    \\  f.onload = () => nav1.log.push("iframe-load");
    \\  f.srcdoc = "<script>addEventListener('load', () => parent.nav1.log.push('child-load'));" +
    \\    "addEventListener('pageshow', () => parent.nav1.log.push('child-pageshow'));<\/script>" +
    \\    "<div id=d></div><div id=e></div>";
    \\  document.body.append(f);
    \\  return true;
    \\})()
;

/// The frame's order, origin, :target after its fragment navigations, and
/// its navigation API's current entry after a same-document traversal back.
const check_script =
    \\(() => {
    \\  const f = nav1.frame, w = f.contentWindow, d = f.contentDocument;
    \\  if (JSON.stringify(nav1.log) !== '["child-load","iframe-load","child-pageshow"]') return false;
    \\  if (w.origin !== self.origin) return false;
    \\  w.location.hash = "d";
    \\  if (d.querySelector(":target") !== d.getElementById("d")) return false;
    \\  w.location.hash = "e";
    \\  if (d.querySelector(":target") !== d.getElementById("e")) return false;
    \\  nav1.index = w.navigation.currentEntry.index;
    \\  w.history.back();
    \\  return true;
    \\})()
;

fn runRound(browser: *browser_mod.Browser, together: anytype) !void {
    try together.reached();
    if (!try truthy(browser, start_script)) return error.NoFrame;
    try waitFor(browser, "nav1.log.length >= 3");
    if (!try truthy(browser, check_script)) return error.AFrameReadWasWrong;
    // The traversal back is a task: the frame's current entry is the one
    // before "#e", and its :target that entry's.
    try waitFor(browser, "nav1.frame.contentWindow.navigation.currentEntry.index === nav1.index - 1");
    if (!try truthy(browser, "nav1.frame.contentDocument.querySelector(':target') !== null")) return error.NoTargetAfterTraversal;
    if (!try truthy(browser, "nav1.frame.remove(), nav1 = null, true")) return error.NotRemoved;
    try collect(browser);
}

fn loadPage(browser: *browser_mod.Browser, page_url: []const u8) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(page, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
}

const Alone = struct {
    fn reached(_: Alone) !void {}
};

test "a frame's load order, origin, fragment and traversal (one Browser)" {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try loadPage(browser, "http://nav1-a.test/page.html");
    try runRound(browser, Alone{});
}

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

const Meeting = struct {
    shared: *Shared,
    point: u32,

    fn reached(self: Meeting) !void {
        try self.shared.meet(self.point);
    }
};

const Side = struct {
    shared: *Shared,
    page_url: []const u8,
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
        try loadPage(browser, self.page_url);
        for (0..rounds) |round| {
            try runRound(browser, Meeting{ .shared = self.shared, .point = @intCast(round + 1) });
        }
    }
};

test "two Browsers on two threads make, navigate and remove frames at once" {
    var shared: Shared = .{};
    var sides = [_]Side{
        .{ .shared = &shared, .page_url = "http://nav1-a.test/page.html" },
        .{ .shared = &shared, .page_url = "https://nav1-b.test/page.html" },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
