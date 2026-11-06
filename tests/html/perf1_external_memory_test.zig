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

/// The page clones a 1,001-node tree ten times a task, for fifteen tasks,
/// and drops every clone - 150,150 nodes - with the event loop turning
/// between tasks, as a page's own does; nothing forces a collection. The
/// clones' wrappers are all V8 sees of them; told about the DOM, it collects
/// once it has grown 64 MB past its last collection, and the loop frees the
/// trees their wrappers' deaths left: the page ends with a fraction of what
/// it dropped. Unreported, V8 never collected and every clone was alive.
fn droppedClonesAreCollected() !void {
    if (engine.capabilities.external_memory == .unsupported) return error.SkipZigTest;
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.tree = document.createElement('div');
        \\tree.innerHTML = '<p>x</p>'.repeat(500);
    );
    try collect(page.browser);
    const before = page.nodes();
    var task: usize = 0;
    while (task < 15) : (task += 1) {
        try page.run("for (let i = 0; i < 10; i++) tree.cloneNode(true);");
        _ = try page.browser.runEventLoopBlocking(5);
    }
    const alive = page.nodes() -| before;
    if (alive >= 100_000) std.debug.print("150 dropped clones of 1,001 nodes over 15 tasks: {d} nodes alive\n", .{alive});
    try testing.expect(alive < 100_000);
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
