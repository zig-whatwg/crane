//! Lane wr1 batch 10, the deep review's appendix-wr1 F2
//! (tmp/redesign/review/source/appendix-wr1.md): which thread touches node
//! memory when a scavenge drops node wrappers.
//!
//! The rule (v8_wrapper.cpp, at NodeWrapperRootsHandler): only ResetRoot
//! touches node memory - the node's slot, the anchor, the registry, the
//! record, the collected callback - and it runs on the isolate's own thread
//! (a Debug check there aborts otherwise). TryResetRoot touches none of them
//! and answers false.
//!
//! Who calls TryResetRoot is the V8 version's: 13.1.203 had no caller (a
//! serial loop calling ResetRoot); V8 15.7.112.43, the one Crane links since
//! lane v8up's port, runs ClearWeaknessProcessor as a platform Job (since
//! b1ea3fc1dbf, 2025-02-24: src/handles/traced-handles.cc
//! ProcessWeakYoungObjects) - up to 3 tasks, one per 8 young TracedNode blocks
//! left, the joining thread calling ResetRoot and every worker TryResetRoot;
//! a handle TryResetRoot answers false for is processed again on the
//! isolate's thread with ResetRoot (lane wr1 b11 re-read it at the merge
//! onto 15.7; lesson workflow-the-linked-v8-is-not-the-v8-source-checkout.md).
//!
//! This file pins the rule at the size where V8 goes parallel: a scavenge
//! that drops more than 8 young TracedNode blocks' worth of node wrappers
//! (TracedNodeBlock::Create: at least 256 nodes a block) empties every slot
//! through ResetRoot - on the agent's thread, or the Debug build aborts -
//! however many of the handles V8's workers offered to TryResetRoot first.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) engine.Reporter {
        return .{ .report = report, .host = self };
    }
};

const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,
    queue: *DeferredTeardown,

    fn open(queue: *DeferredTeardown) !Page {
        test_process.start();
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &test_process.no_hooks,
            .host = null,
            .deferred_teardown = queue,
        });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm, .queue = queue };
    }

    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    /// Requested full collections, twice, their releases drained.
    fn fullGC(self: Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        self.queue.drainAll();
    }

    /// At least `n` scavenges, then the agent's pump - its posted tasks and
    /// its safe point, where the drain a scavenge owes runs - and its queue.
    fn minorGC(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
        self.queue.drainAll();
    }
};

/// The adapter's counter `name` with the page's isolate entered.
fn counter(page: Page, name: []const u8) !i64 {
    const entered = page.enter();
    defer page.leave(entered);
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    std.debug.print("the adapter reports no counter named {s}\n", .{name});
    return error.CounterMissing;
}

test "wr10 F2: a scavenge dropping more than 8 young blocks of node wrappers empties every slot through ResetRoot on the agent's thread, whatever V8's workers offered to TryResetRoot" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    const dropped_before = ffi.v8_test_NodeWrappers_Dropped(page.isolate());
    const tries_before = ffi.v8_test_NodeWrappers_TryResetRootCalls(page.isolate());
    const wrappers_before = try counter(page, "node_wrappers");

    // 6,000 lone divs, each wrapped and dropped at once: 6,000 young
    // TracedReferences, about 20 blocks (a block holds 256 nodes or a few
    // more, what its allocation's rounding leaves room for), all dropped by
    // the scavenges that follow - V8's unmodified-API-object rule
    // (tests/v8/wr8_young_generation_test.zig pins it on this wrapper shape).
    const lone = 6000;
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(6000); }");
    try page.minorGC(4);

    const dropped = ffi.v8_test_NodeWrappers_Dropped(page.isolate()) - dropped_before;
    const tries = ffi.v8_test_NodeWrappers_TryResetRootCalls(page.isolate()) - tries_before;
    const live = try counter(page, "node_wrappers") - wrappers_before;
    std.debug.print("wr10 F2 fact: {d} of {d} lone wrappers dropped through ResetRoot; TryResetRoot called {d} times; live node wrappers +{d}\n", .{ dropped, lone, tries, live });
    // Every drop went through ResetRoot, which aborts off the agent's thread
    // in this (Debug) build; the few a scavenge keeps are the last ones the
    // loop's registers and feedback still name (wr8's 1,900 of 2,000).
    try testing.expect(dropped >= lone * 95 / 100);
    try testing.expect(live < lone * 5 / 100);
    // V8 15.7's workers may have offered some of these handles to
    // TryResetRoot first (0 when the Job ran on the joining thread alone):
    // it answered false and touched nothing, so every one of them was reset
    // by ResetRoot - counted in `dropped` above. Never more offers than
    // handles processed.
    try testing.expect(tries <= lone + 1024);
}
