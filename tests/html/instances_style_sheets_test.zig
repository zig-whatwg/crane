//! Two Browsers on two threads build, edit, adopt and drop style sheets at the
//! same time, and each sees only its own cascade (docs/instances.md: a sheet,
//! its rule tree, its CSSOM objects and a document's style engine belong to
//! the document's agent; the UA sheet is the one process-wide part, and it is
//! read-only).
//!
//! Each round both Browsers load a page, then together: insert a <style>
//! whose colour is their own, edit its rules through CSSOM (insertRule,
//! a rule's style, deleteRule), adopt a constructed sheet, read
//! getComputedStyle, then remove the style element while script still holds
//! its sheet and rules, and collect. Each Browser allocates from a
//! DebugAllocator of its own, without stack traces, which fails the test on a
//! leak (the shared std.testing.allocator would make the threads take turns:
//! docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://style2.test/page.html";
const page =
    \\<!doctype html><head><title>t</title></head><body><div id=t>x</div><div id=host></div></body>
;
const rounds = 10;
const edits_per_round = 200;

fn startBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
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

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
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
    try engine.runInRealm(realm, Collect.steps, agent);
}

/// One round on `browser`, whose colour channel is `tone`.
fn runRound(browser: *browser_mod.Browser, tone: u8, together: anytype) !void {
    var buffer: [2048]u8 = undefined;
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(page, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
    try together.reached();
    try collect(browser);
    try expectScript(browser, try std.fmt.bufPrint(&buffer,
        \\(() => {{
        \\  const t = document.getElementById('t');
        \\  const style = document.createElement('style');
        \\  style.textContent = '#t {{ color: rgb({d}, {d}, {d}) }} @media all {{ #t {{ margin-left: 1px }} }}';
        \\  document.head.appendChild(style);
        \\  const sheet = style.sheet;
        \\  for (let i = 0; i < {d}; i++) {{
        \\    sheet.insertRule('#t {{ padding-left: ' + i + 'px }}', sheet.cssRules.length);
        \\    if (getComputedStyle(t).paddingLeft !== i + 'px') return false;
        \\    sheet.cssRules[0].style.color = 'rgb({d}, {d}, ' + (i % 200) + ')';
        \\    sheet.deleteRule(sheet.cssRules.length - 1);
        \\  }}
        \\  const adopted = new CSSStyleSheet();
        \\  adopted.replaceSync('#t {{ text-transform: uppercase }}');
        \\  document.adoptedStyleSheets = [adopted];
        \\  const root = document.getElementById('host').attachShadow({{ mode: 'open' }});
        \\  root.innerHTML = '<style>:host {{ padding-top: {d}px }}</style><span>s</span>';
        \\  const ok = getComputedStyle(t).color === 'rgb({d}, {d}, ' + (({d} - 1) % 200) + ')' &&
        \\    getComputedStyle(t).textTransform === 'uppercase' &&
        \\    getComputedStyle(document.getElementById('host')).paddingTop === '{d}px';
        \\  globalThis.kept = [sheet, sheet.cssRules, sheet.cssRules[0]];
        \\  style.remove();
        \\  return ok && kept[1].length === 2 && kept[0].ownerNode === null;
        \\}})()
    , .{ tone, tone, tone, edits_per_round, tone, tone, tone, tone, tone, edits_per_round, tone }));
    try expectScript(browser, "globalThis.kept = null; true");
}

const Alone = struct {
    fn reached(_: Alone) !void {}
};

test "one Browser: a round of style sheet edits" {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    try runRound(browser, 7, Alone{});
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
    tone: u8,
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
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        for (0..rounds) |round| {
            try runRound(browser, self.tone, Meeting{ .shared = self.shared, .point = @intCast(round + 1) });
        }
    }
};

test "two Browsers on two threads edit, adopt and drop style sheets at once, each with its own cascade" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared, .tone = 11 }, .{ .shared = &shared, .tone = 22 } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
