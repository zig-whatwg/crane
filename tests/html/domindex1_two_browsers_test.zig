//! Two Browsers on two threads change IDs and names and read getElementById
//! and the Document's and Window's named properties at the same time (lane
//! domindex1): each document's tree scope maps (dom.tree_ordered_map) are its
//! own state, kept by its own mutations, and the one hook table the maps are
//! reached through is written once at process start, so neither Browser's
//! answers see the other's elements and neither frees what the other reads.
//!
//! Each Browser allocates from a DebugAllocator of its own, without stack
//! traces (std.testing.allocator's one lock would make the two take turns;
//! docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md),
//! which still fails the test on a leak.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://domindex1.test/page.html";
const page = "<!doctype html><body><div id=host></div></body>";
const rounds = 8;

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

/// The round's script: 400 elements with IDs and names made, renamed, moved
/// and removed, every read checked against what the round set. `tag` (a
/// global the side sets first) makes this Browser's names its own.
const round_script =
    \\(() => {
    \\  const host = document.getElementById("host");
    \\  const made = [];
    \\  for (let i = 0; i < 400; i++) {
    \\    const e = document.createElement(i % 2 ? "form" : "img");
    \\    e.id = tag + i;
    \\    e.setAttribute("name", tag + "n" + (i % 20));
    \\    host.append(e);
    \\    made.push(e);
    \\  }
    \\  for (let i = 0; i < 400; i++) {
    \\    if (document.getElementById(tag + i) !== made[i]) return false;
    \\    if (window[tag + i] !== made[i]) return false;
    \\  }
    \\  const list = document[tag + "n3"];
    \\  if (!(list instanceof HTMLCollection) || list.length !== 20) return false;
    \\  if (document[tag + "n3"] !== list) return false;
    \\  for (let i = 0; i < 400; i += 2) made[i].id = tag + "moved" + i;
    \\  for (let i = 0; i < 400; i += 2) {
    \\    if (document.getElementById(tag + i) !== null) return false;
    \\    if (document.getElementById(tag + "moved" + i) !== made[i]) return false;
    \\  }
    \\  host.prepend(made[399]);
    \\  if (document[tag + "n19"][0] !== made[399]) return false;
    \\  for (const e of made) e.remove();
    \\  if (document.getElementById(tag + "1") !== null) return false;
    \\  if ((tag + "n3") in document) return false;
    \\  return list.length === 0;
    \\})()
;

fn runRound(browser: *browser_mod.Browser, together: anytype) !void {
    try together.reached();
    if (!try truthy(browser, round_script)) return error.ANamedReadWasWrong;
    try collect(browser);
}

fn loadPage(browser: *browser_mod.Browser, tag: []const u8) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(page, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
    var buffer: [64]u8 = undefined;
    if (!try truthy(browser, try std.fmt.bufPrint(&buffer, "globalThis.tag = '{s}'; true", .{tag}))) return error.NoTag;
}

const Alone = struct {
    fn reached(_: Alone) !void {}
};

test "getElementById and named properties follow ID and name changes (one Browser)" {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try loadPage(browser, "a");
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
    tag: []const u8,
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
        try loadPage(browser, self.tag);
        for (0..rounds) |round| {
            try runRound(browser, Meeting{ .shared = self.shared, .point = @intCast(round + 1) });
        }
    }
};

test "two Browsers on two threads change IDs and names and read named properties at once" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared, .tag = "x" }, .{ .shared = &shared, .tag = "y" } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
