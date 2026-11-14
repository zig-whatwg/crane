//! Queueing a mutation record makes no allocation that lives only for the
//! call (lane wr1 batch 6: the ed-mo-parse-page cost pair).
//!
//! DOM "queue a mutation record" step 1 makes interestedObservers, an ordered
//! map that lives for the one call. It was an ArrayList on the call's
//! allocator: 6 entries of 24 bytes, 144 bytes, allocated and freed by every
//! record. Under the WPT runner's DebugAllocator (tests/wpt_runner/
//! runner_allocator.zig: 128 KiB buckets, a freed slot never reused, a bucket
//! unmapped when its last slot is freed) that costs nothing only while
//! something longer-lived shares its size class's bucket. The wrapper
//! redesign's P6 shrank a MutationRecord's own state (128 bytes) and its holds
//! (24 bytes a node) out of the 256-byte class into the 128-byte one, so the
//! list was alone there: every record mapped a bucket, faulted it in and
//! unmapped it - crane/ed-mo-parse-page.html (a 2,500-section parse under a
//! subtree observer, ~27,500 records) ran 2.25x slower than P2 and P5
//! (`sample`: `queueMutationRecordInternal` 56.3 against 4.2 samples a run,
//! under it DebugAllocator alloc/free, `__mmap` and `__munmap`). Lesson
//! docs/lessons/debugging-a-per-call-allocation-in-a-lonely-size-class-maps-
//! a-page.md: put call-lifetime data on the stack.
//!
//! The test counts, through a counting allocator handed to
//! queueTreeMutationRecord as the call's allocator, the frees each queueing
//! makes: none - everything the call allocates belongs to the record. Without
//! a timer: the count is the cost's cause, whatever the allocator. A second
//! case gives one node more observers than the stack holds (the heap
//! fallback), and every one still gets its record.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

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

/// c_allocator, counting the allocations and frees made through it.
const Counting = struct {
    allocations: usize = 0,
    frees: usize = 0,

    fn allocator(self: *Counting) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        self.allocations += 1;
        return std.heap.c_allocator.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        return std.heap.c_allocator.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        self.allocations += 1;
        return std.heap.c_allocator.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        self.frees += 1;
        std.heap.c_allocator.rawFree(memory, alignment, ret_addr);
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

    /// The Browser's end, in its order (Browser.deinit).
    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.releaseNodeWrappers(self.agent);
        self.queue.drainAll();
        engine.destroyAgent(self.agent);
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        if (reports.count != 0) return error.ScriptFailed;
    }

    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        if (reports.count != 0) return error.ScriptFailed;
        return engine.toBoolean(self.realm, held.value);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        return engine.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }
};

/// An HTML document of its own, bound to `d`.
const html_document = "globalThis.d = new Document().implementation.createHTMLDocument('');\n";

/// `records` childList records for `target` (adding `kid`), each queued by a
/// call of its own with `counting` as the call's allocator, inside the realm
/// (DOM "queue a tree mutation record", as the insert steps call it): the
/// frees each call made, summed.
const Queueing = struct {
    counting: *Counting,
    target: *runtime.Instance,
    kid: *dom.NodeBase,
    records: usize,
    frees_in_calls: usize = 0,
    failed: ?anyerror = null,

    fn steps(data: ?*anyopaque) void {
        const self: *Queueing = @ptrCast(@alignCast(data.?));
        for (0..self.records) |_| {
            const before = self.counting.frees;
            dom.mutation_observer_algorithms.queueTreeMutationRecord(self.counting.allocator(), self.target, &.{self.kid}, &.{}, null, null) catch |err| {
                self.failed = err;
                return;
            };
            self.frees_in_calls += self.counting.frees - before;
        }
    }
};

test "wr6: queueing a mutation record frees nothing during the call - interestedObservers lives on the stack, not on the call's allocator" {
    test_process.start();
    // Outlives the page: the queued records' state is the counting
    // allocator's, freed when the records go.
    var counting: Counting = .{};
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(html_document ++
        \\globalThis.box = d.createElement('div');
        \\globalThis.kid = d.createElement('span');
        \\globalThis.mo = new MutationObserver(() => {});
        \\mo.observe(box, { childList: true, subtree: true });
    );
    const box = try page.instance("box");
    const kid = try page.instance("kid");
    var queueing: Queueing = .{
        .counting = &counting,
        .target = box,
        .kid = dom.instance_bridge.getNodeBase(kid) orelse return error.NotANode,
        .records = 100,
    };
    try engine.runInRealm(page.realm, Queueing.steps, &queueing);
    if (queueing.failed) |err| return err;
    // The records' own state came from the call's allocator...
    try testing.expect(counting.allocations >= queueing.records);
    // ...and nothing of it was freed inside a call: a per-record call-lifetime
    // allocation is what made every record map and unmap a DebugAllocator
    // bucket once its size class had no long-lived neighbour.
    try testing.expectEqual(@as(usize, 0), queueing.frees_in_calls);
    // Every record is queued, in order.
    try testing.expect(try page.holds(
        \\(() => {
        \\  const records = mo.takeRecords();
        \\  return records.length === 100 && records.every((r) => r.type === 'childList' && r.target === box && r.addedNodes[0] === kid);
        \\})()
    ));
    try page.run("mo.disconnect();");
}

test "wr6: a node with more interested observers than the stack holds gives each its record" {
    test_process.start();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    // 40 observers, 20 on the target and 20 with subtree on its parent
    // (step 2's inclusive ancestors): interestedObservers grows past its
    // stack buffer onto the call's allocator. The test agent has no host, so
    // the records wait in each observer's queue (no notify microtask) and
    // takeRecords() reads them.
    try page.run(html_document ++
        \\globalThis.outer = d.createElement('div');
        \\globalThis.box = outer.appendChild(d.createElement('div'));
        \\globalThis.observers = [];
        \\for (let i = 0; i < 40; i++) {
        \\  const mo = new MutationObserver(() => {});
        \\  mo.observe(i % 2 ? outer : box, { childList: true, subtree: true });
        \\  observers.push(mo);
        \\}
        \\globalThis.kid = box.appendChild(d.createElement('span'));
    );
    try testing.expect(try page.holds(
        \\observers.every((mo) => {
        \\  const records = mo.takeRecords();
        \\  return records.length === 1 && records[0].target === box && records[0].addedNodes[0] === kid;
        \\})
    ));
    try page.run("for (const mo of observers) mo.disconnect();");
}
