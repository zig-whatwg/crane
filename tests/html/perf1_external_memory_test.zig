//! Lane perf1: a Browser tells its window agent's engine about its DOM
//! (runtime.BrowserScope.dom_memory, counted by dom.instance_bridge;
//! engine.AgentOptions.external_memory).
//!
//! A wrapper is a few dozen bytes of the engine's heap and keeps its node's
//! whole tree alive, so a page that clones a tree and drops the clone - the
//! benchmark suite's dom.clone-node - grows its native memory by megabytes
//! per clone while the engine sees almost nothing, and never collects: 650
//! clones of an 840-node tree kept 548,150 nodes, 1.7 GB (perf round 0's
//! tree page, 1.6 GB). Told about the DOM, V8 collects as it grows, as it did
//! for Blink's DOM before Blink's unified heap (V8GCController::
//! reportDOMMemoryUsageToV8, Chromium 45).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");

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

    /// Live nodes of the Browser.
    fn nodes(self: Page) usize {
        return dom.instance_bridge.entryCount(self.browser.scope);
    }

    /// The Browser's own count of its DOM memory alive now - what it
    /// reports to the engine (runtime.BrowserScope.dom_memory).
    fn live(self: Page) usize {
        return self.browser.scope.dom_memory.live;
    }

    /// The engine's count of the agent's external memory.
    fn external(self: Page) !usize {
        const agent = self.browser.getAgent() orelse return error.NoAgent;
        if (engine.capabilities.heap_statistics != .unsupported) return engine.heapStatistics(agent).external;
        return error.SkipZigTest;
    }
};

/// Two full collections from native code, outside any script: the deferred
/// teardown queue drains after each.
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

/// The page clones a 1,001-node tree ten times a task, for sixty tasks, and
/// drops every clone - 600,600 nodes, over 100 MB of DOM - with the event
/// loop turning between tasks, as a page's own does; nothing forces a
/// collection. The clones' wrappers are all V8 sees of them; told about the
/// DOM, it collects as the reported bytes grow, and the loop frees the trees
/// their wrappers' deaths left. Unreported, V8 never collected and every
/// clone was alive.
///
/// The bar is in BYTES, because bytes are what V8 paces by: the DOM alive
/// never passes 64 MB over the start - V8's own soft limit for external
/// memory (heap.h kExternalAllocationSoftLimit), well clear of the measured
/// peaks - and it fell at least once, and the engine was told. It was a node
/// count ("fewer than 100,000 of 150,150 alive after 15 tasks") until lane
/// nm1's layout batch made a div 48 bytes and a Text 32 bytes smaller: a node
/// count moves with every size change. MEASURED with this workload (server1,
/// 2026-11-14): V8 collected at 38.1 MB over the start with 192,188 nodes
/// alive on main 497cbc5559f, and at 36.9 MB with 230,226 nodes alive on the
/// smaller nodes - the same bytes, 20% more nodes - and the old bar, which
/// sat between a first collection after task 5 and one after task 6, read
/// 100,096.
fn droppedClonesAreCollected() !void {
    if (engine.capabilities.external_memory == .unsupported) return error.SkipZigTest;
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.tree = document.createElement('div');
        \\tree.innerHTML = '<p>x</p>'.repeat(500);
    );
    try collect(page.browser);
    const nodes_before = page.nodes();
    const live_before = page.live();
    const told_before = try page.external();
    var peak_live: usize = 0;
    var peak_nodes: usize = 0;
    var peak_told: usize = 0;
    var previous_live: usize = 0;
    var falls: usize = 0;
    var task: usize = 0;
    while (task < 60) : (task += 1) {
        try page.run("for (let i = 0; i < 10; i++) tree.cloneNode(true);");
        _ = try page.browser.runEventLoopBlocking(5);
        const live = page.live() -| live_before;
        if (live > peak_live) {
            peak_live = live;
            peak_nodes = page.nodes() -| nodes_before;
        }
        if (live < previous_live) falls += 1;
        previous_live = live;
        peak_told = @max(peak_told, (try page.external()) -| told_before);
    }
    const limit: usize = 64 * 1024 * 1024;
    const collected = peak_live <= limit and falls != 0 and peak_told != 0;
    if (!collected) {
        std.debug.print("600 dropped clones of 1,001 nodes over 60 tasks: the DOM alive peaked at {d} B over the start (limit {d}), with {d} nodes alive at that peak (an observation, not a bar); it fell {d} times; the engine was told of at most {d} B\n", .{ peak_live, limit, peak_nodes, falls, peak_told });
        if (peak_told == 0) std.debug.print("the engine was told nothing about the DOM: it cannot collect what it cannot see\n", .{});
        if (falls == 0) std.debug.print("the DOM alive never fell: no collection freed a dropped clone\n", .{});
    }
    try testing.expect(collected);
}

test "dropped clones of a tree are collected as the DOM grows, with no forced collection" {
    try onFreshThread(droppedClonesAreCollected);
}

/// The engine's count follows the DOM: up by the nodes' storage once a
/// binding exit reports it, and back down once they are freed.
fn theEngineCountFollowsTheDom() !void {
    if (engine.capabilities.external_memory == .unsupported) return error.SkipZigTest;
    const page = try Page.open();
    defer page.close();
    const start = try page.external();
    try page.run(
        \\globalThis.keep = document.createElement('div');
        \\keep.innerHTML = '<p>x</p>'.repeat(2000);
    );
    const grown = (try page.external()) -| start;
    // 4,001 nodes: each a slab slot, a state block and a NodeBase.
    const at_least = 4001 * (@sizeOf(dom.NodeBase) + 32);
    if (grown < at_least) std.debug.print("4,001 nodes made: the engine's external count grew {d} bytes, under {d}\n", .{ grown, at_least });
    try testing.expect(grown >= at_least);

    try page.run("keep = null;");
    try collect(page.browser);
    // A binding exit after the free reports it.
    try page.run("void document.body;");
    const now = try page.external();
    const step = @import("runtime").gc.ExternalMemory.report_step;
    if (now > start + step) std.debug.print("after the free: {d} bytes over the start\n", .{now - start});
    try testing.expect(now <= start + step);
}

test "the engine's external memory count goes up with the DOM and back down when its nodes are freed" {
    try onFreshThread(theEngineCountFollowsTheDom);
}
