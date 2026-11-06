//! Lane perf1: the deferred teardown queue's memory bound weighs a garbage
//! tree by its nodes.
//!
//! The queue (runtime.gc.DeferredTeardown) frees garbage trees a slice at a
//! time between tasks, and past `high_water` queued nodes the binding exit
//! back into script frees down to it, so a script that makes garbage cannot
//! grow the queue without bound. The bound counts nodes, so each tree must
//! weigh what it holds: weighed at most 64 nodes (the walk cap the bound
//! used), a page that replaces a list of 900 nodes by innerHTML in a loop -
//! the benchmark suite's dom.inner-html-set - let 1,562 trees of any size
//! wait, 1.39M nodes and 4 GB (perf round 0: the innerhtml page's 3.6 GB).
//! WebKit frees such a tree at once (its last Ref ends in
//! removeDetachedChildrenInContainer, ContainerNodeAlgorithms.cpp); Crane
//! frees it one slice later (refcount design decision D8), bounded by the
//! queue.
//!
//! The case runs ONE script, so no task can turn the event loop - only the
//! bound can free inside it.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
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

    /// Live platform objects of the Browser: its slab's slots in use.
    fn live(self: Page) usize {
        return self.browser.scope.slab.stats().currently_allocated;
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

/// One script replaces a connected list of 1,001 nodes (a ul, 500 li, 500
/// texts) 150 times by innerHTML: 149 lists - 149,149 nodes - become
/// garbage, none of them wrapped, so only the counts free them (refcount step
/// 7). Weighed by their nodes, the queue passes high_water (100,000) at the
/// hundredth and the binding exits after it free down to the bound: the
/// script ends with about 100,000 nodes waiting, not every list it dropped.
/// Then the list is removed and a collection drains the queue: every node
/// the script made is gone.
fn replacedListsStayBoundedByTheirNodes() !void {
    const page = try Page.open();
    defer page.close();
    const before = page.live();
    try page.run(
        \\{
        \\  const box = document.body.appendChild(document.createElement('div'));
        \\  box.id = 'box';
        \\  const list = '<ul>' + '<li>x</li>'.repeat(500) + '</ul>';
        \\  for (let i = 0; i < 150; i++) box.innerHTML = list;
        \\}
    );
    const grown = page.live() -| before;
    if (grown >= 125_000) std.debug.print("150 replaced lists of 1,001 nodes in one script: {d} objects still alive at its end\n", .{grown});
    try testing.expect(grown < 125_000);

    try page.run("document.getElementById('box').remove();");
    try collect(page.browser);
    const left = page.live() -| before;
    if (left > 64) std.debug.print("after the list's removal and a collection: {d} objects still alive\n", .{left});
    try testing.expect(left <= 64);
}

test "lists replaced by innerHTML inside one script stay bounded by the queue's high water in nodes, not in trees" {
    try onFreshThread(replacedListsStayBoundedByTheirNodes);
}
