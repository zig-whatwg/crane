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
const loop_settle = @import("loop_settle.zig");

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
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
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

// ============================================================================
// Inside a callback (lane mem1, follow-up A)
// ============================================================================

/// The joins a run makes: past the undo history's 1,000 steps, each join's
/// step drops the trees of the join 1,000 before it.
const joins_total = 3000;

/// The peak of the Browser's platform objects while `shape` runs edit4's
/// delete-join row `joins_total` times in a contenteditable host: the slab
/// never gives a slab back, so its capacity after the run is the most objects
/// that were ever alive at once.
const JoinShape = enum {
    /// ONE timer callback runs them all: the way a page runs a long loop.
    one_callback,
    /// Timer callbacks of 100, the loop idle between them.
    spread,
};

/// What a run left to read: its peak, and the nodes the queue freed at
/// binding returns inside callbacks (DeferredTeardown.freed_in_callbacks).
const JoinRun = struct { peak: usize, freed_in_callbacks: usize };

fn joinPeak(shape: JoinShape) !JoinRun {
    // The churn tests' allocator: every join makes and frees hundreds of
    // blocks (tests/AGENTS.md, "Tests come first").
    var churn = @import("root").poisoning.ChurnAllocator.init("perf1_garbage_weight_test: delete-joins in timer callbacks");
    var run: JoinRun = .{ .peak = 0, .freed_in_callbacks = 0 };
    {
        const browser = try browser_mod.Browser.init(churn.allocator(), .{ .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigate("about:blank", .window);
        const context = browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        const page: Page = .{ .browser = browser };
        try page.run(
            \\globalThis.host = document.body.appendChild(document.createElement('div'));
            \\host.contentEditable = 'true';
            \\host.focus();
            \\globalThis.joins = (n) => {
            \\  for (let i = 0; i < n; i++) {
            \\    host.innerHTML = '<p><b>foo</b></p><p><span style="color:red">bar</span></p>';
            \\    const r = document.createRange();
            \\    r.setStart(host.lastChild.firstChild.firstChild, 0);
            \\    r.collapse(true);
            \\    getSelection().removeAllRanges();
            \\    getSelection().addRange(r);
            \\    document.execCommand('delete');
            \\  }
            \\  if (host.childNodes.length !== 1) throw new Error('no join: ' + host.innerHTML);
            \\};
        );
        switch (shape) {
            .one_callback => {
                try page.run(std.fmt.comptimePrint("setTimeout(() => joins({d}), 0);", .{joins_total}));
                try loop_settle.settle(browser);
            },
            .spread => for (0..joins_total / 100) |_| {
                try page.run("setTimeout(() => joins(100), 0);");
                try loop_settle.settle(browser);
            },
        }
        run = .{
            .peak = browser.scope.slab.stats().total_capacity,
            .freed_in_callbacks = browser.agent_host.deferred_teardown.freed_in_callbacks,
        };
    }
    try churn.deinit();
    return run;
}

/// What one long callback piles up is bounded as a spread run's is: the
/// trees and the collected wrappers' natives it made itself are freed at the
/// binding returns into its own script (the frames below it were suspended
/// before those objects existed - the fresh rule), a slice at a time. Before
/// this, nothing was freed until the callback returned: 8,000 joins in one
/// timer callback peaked at 56.6 MB Zig-side against 5.8 MB spread over 80
/// callbacks (gc_bench, chat2), with 56,000 Ranges and 57,000 queued nodes
/// waiting at the callback's end. Here (server1, Debug, slab objects at the
/// peak): 42,075 in one callback against 12,750 spread (3.3x); 40,290 with
/// the trees' rule alone; 24,225 (1.9x) with the finalizers' too - and the
/// same with the fresh node wrappers' releases (tests/v8/
/// mem1_fresh_node_release_test pins those), and the same again with the
/// queue's byte bound at half the live DOM instead of all of it, with 2,560
/// nodes freed inside the callback in every variant. The bound is 2.5x on
/// those measurements. What the remaining 1.9x is, by a census of live
/// objects by interface at each callback's end (lane mem1): the trees the
/// queue holds under its byte bound's 2 MB FLOOR - 14,440 queued nodes,
/// 2,025,600 bytes dying against 638,928 live, where max(2 MB, live) is the
/// floor - against 800 queued nodes and 112,000 bytes for the largest
/// spread callback; the paragraphs, spans, texts and b elements are 11,060
/// of the 11,210 extra objects, Ranges 156. The floor is V8's own smallest
/// step for its old generation's limit in its conservative mode
/// (MemoryController::MinimumAllocationLimitGrowingStep, 2 pages of at
/// least 1 MB; 8 otherwise: V8 15.7.112.43 src/heap/heap-controller.cc:
/// 134-142), so a test whose live DOM is under 2 MB keeps up to 2 MB of it.
fn oneCallbackStaysNearTheSpreadPeak() !void {
    const spread = try joinPeak(.spread);
    const one = try joinPeak(.one_callback);
    std.debug.print("{d} joins: one callback peaked at {d} objects ({d} nodes freed inside callbacks), callbacks of 100 at {d} ({d})\n", .{ joins_total, one.peak, one.freed_in_callbacks, spread.peak, spread.freed_in_callbacks });
    if (2 * one.peak > 5 * spread.peak) return error.OneCallbackPeakUnbounded;
}

test "3,000 delete-joins in one timer callback peak within 2.5x of the same joins spread over callbacks of 100" {
    try onFreshThread(oneCallbackStaysNearTheSpreadPeak);
}
