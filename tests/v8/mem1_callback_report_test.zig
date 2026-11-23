//! Inside a callback, a binding's return into the callback's own script
//! tells V8 how the host's DOM memory moved (lane mem1, the report step of
//! follow-up A), and runs nothing after the report but what the fresh rule
//! admits.
//!
//! The report was owed only to depth zero (the outermost binding exit, and
//! the microtask checkpoint outside a DOM algorithm: external_memory.zig).
//! Most of a page's script runs inside callbacks, whose bindings never
//! return at depth zero, so a DOM-heavy callback that allocates little on
//! V8's own heap told V8 nothing until it returned, and nothing collected
//! the wrappers it dropped. Blink's unified heap has no such gap: every
//! cppgc allocation reaches V8's global limit as it is made (V8 15.7.112.43
//! src/heap/cppgc-js/cpp-heap.cc:1055-1107, CppHeap::
//! ReportBufferedAllocationSizeIfPossible, every 128 KB).
//!
//! The collection a report starts runs nothing of Crane's but bookkeeping -
//! any allocation inside a callback can start the same one - but the
//! depth-zero report's call DRAINS the agent's finalizer queue when V8
//! returns (v8_ExternalMemoryAccounter_Update), which inside a callback
//! would finalize objects older than the callback beneath frames that may
//! hold them. So the in-callback report is a call of its own, with no drain;
//! what its collection queued runs by the fresh rule at the next binding
//! return. The depth-zero report and the checkpoint keep their drain, in the
//! order V8's first pass found the dead.
//!
//! Each test has its own agent, its own figure moved by hand (as
//! tests/v8/external_memory_test.zig does) and its own queue; the callback is
//! the queue's bookkeeping (`enterCallback` with the realm's slab entry, as
//! dom_algorithm.enterCallback makes it), and the scripts run inside it.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const ffi = v8.ffi;
const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Ignored = struct {
    fn report(_: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        std.debug.print("reported: {s}\n", .{info.message});
    }
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,
    queue: *DeferredTeardown,
    memory: *ExternalMemory,

    fn open(queue: *DeferredTeardown, memory: *ExternalMemory) !Page {
        test_process.start();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .host = null,
            .deferred_teardown = queue,
            .external_memory = memory,
        });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm, .queue = queue, .memory = memory };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn run(self: Page, source: []const u8) !void {
        try protocol.runClassicScript(self.realm, .{ .utf8 = source }, "", null, Ignored.reporter);
    }

    /// One binding call returning into script (a Document's attribute).
    fn callBinding(self: Page) !void {
        try self.run("void (globalThis.doc ??= new Document()).nodeType;");
    }

    /// V8's own count of the isolate's external memory.
    fn external(self: Page) usize {
        return ffi.v8_Isolate_GetExternalMemory(self.isolate());
    }

    fn reported(self: Page) usize {
        return v8.external_memory.reportedOn(self.isolate());
    }

    /// A callback invocation begins: its entry is the realm's slab's next
    /// generation (dom_algorithm.enterCallback's `entryOf`).
    fn enterCallback(self: Page) !DeferredTeardown.OuterCallback {
        const scope = self.realm.browserScope() orelse return error.NoScope;
        return self.queue.enterCallback(.{ .slab = &scope.slab, .generation = scope.slab.generationNow() });
    }

    /// The agent's full collections so far (the adapter's diagnostic
    /// counters).
    fn fullCollections(self: Page) !i64 {
        _ = self;
        var bytes: [64 * @sizeOf(protocol.Counter)]u8 align(@alignOf(protocol.Counter)) = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(&bytes);
        const read = try protocol.diagnosticCounters(fixed.allocator());
        for (read) |c| if (std.mem.eql(u8, c.name, "full_gc_count")) return c.value;
        return error.NoCounter;
    }
};

/// Plain objects of the agent's bootstrap context with a finalizer of the
/// test's (as the wrapper cache arms a wrapper): never fresh - not a wrapper
/// cache record - so they wait for depth zero wherever they die.
const Probe = struct {
    const max = 8;
    isolate: *ffi.Isolate,
    handles: [max]?*ffi.Object = @splat(null),
    indexes: [max]u8 = undefined,
    count: usize = 0,
    unlink_order: [max]u8 = @splat(0xff),
    unlinks: usize = 0,
    order: [max]u8 = @splat(0xff),
    finalizes: usize = 0,
    /// The DOM-algorithm depth each finalizer ran at.
    depths: [max]u32 = @splat(0xffff),
    queue: *DeferredTeardown,

    /// One object of `context`, held only by its weak handle: the next
    /// full collection finds it dead.
    fn arm(self: *Probe, context: *ffi.Context) !void {
        const i = self.count;
        self.indexes[i] = @intCast(i);
        self.count += 1;
        const entered = Entered.of(self.isolate);
        defer entered.leave();
        ffi.v8_Context_Enter(context);
        defer ffi.v8_Context_Exit(context);
        const scope = ffi.v8_HandleScope_New(self.isolate);
        const object = ffi.v8_Object_New(self.isolate) orelse return error.ObjectCreationFailed;
        if (scope) |s| ffi.v8_HandleScope_Dispose(s);
        self.handles[i] = object;
        ffi.v8_Global_SetWeakFinalizer(@ptrCast(object), @ptrCast(&self.indexes[i]), unlinked, finalized);
    }

    fn unlinked(data: ?*anyopaque, _: usize) callconv(.c) void {
        const index: *u8 = @ptrCast(data.?);
        const self = &probe.?;
        self.unlink_order[self.unlinks] = index.*;
        self.unlinks += 1;
    }

    fn finalized(data: ?*anyopaque, _: usize) callconv(.c) void {
        const index: *u8 = @ptrCast(data.?);
        const self = &probe.?;
        self.order[self.finalizes] = index.*;
        self.depths[self.finalizes] = self.queue.algorithm_depth;
        self.finalizes += 1;
        if (self.handles[index.*]) |handle| ffi.v8_Object_Dispose(handle);
        self.handles[index.*] = null;
    }
};

/// The probe of the running test: its finalizers find it here.
var probe: ?Probe = null;

/// The isolate entered on this thread for a direct FFI call, and left after
/// it when it was not already.
const Entered = struct {
    isolate: ?*ffi.Isolate,

    fn of(isolate: *ffi.Isolate) Entered {
        if (ffi.v8_Isolate_GetCurrent() == isolate) return .{ .isolate = null };
        ffi.v8_Isolate_Enter(isolate);
        return .{ .isolate = isolate };
    }

    fn leave(self: Entered) void {
        if (self.isolate) |isolate| ffi.v8_Isolate_Exit(isolate);
    }
};

fn contextOf(realm: runtime.Context) *ffi.Context {
    return @ptrCast(@alignCast(realm.engine_ctx.?));
}

/// Reports past V8's soft limit (64 MB above the low since its last
/// mark-compact) inside the current state, a binding return each, until a
/// full collection finished or `max` reports were made: whether one did.
fn reportUntilCollected(page: Page, max: usize) !bool {
    const before = try page.fullCollections();
    var i: usize = 0;
    while (i < max) : (i += 1) {
        page.memory.add(1 << 20);
        try page.callBinding();
        if (try page.fullCollections() > before) return true;
    }
    return false;
}

test "inside a callback, a binding's return tells V8 how the DOM grew" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    const page = try Page.open(&queue, &memory);
    defer page.close();
    try page.callBinding();

    const start = page.external();
    const outer = try page.enterCallback();
    memory.add(4 << 20);
    try page.callBinding();
    try testing.expectEqual(memory.live, page.reported());
    try testing.expectEqual(start + memory.live, page.external());
    queue.leaveCallback(outer);
}

test "inside a callback, the growth it reports makes V8 collect there, with no forced collection and no task turn" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    const page = try Page.open(&queue, &memory);
    defer page.close();
    try page.callBinding();

    const outer = try page.enterCallback();
    const collected = try reportUntilCollected(page, 800);
    queue.leaveCallback(outer);
    try testing.expect(collected);
}

test "an in-callback report's collection finalizes nothing older than the callback: that waits for depth zero" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    const page = try Page.open(&queue, &memory);
    defer page.close();
    try page.callBinding();
    const context = contextOf(page.realm);

    probe = .{ .isolate = page.isolate(), .queue = &queue };
    defer probe = null;
    // Armed and dropped before the callback: old.
    try probe.?.arm(context);
    try probe.?.arm(context);

    const outer = try page.enterCallback();
    const collected = try reportUntilCollected(page, 800);
    try testing.expect(collected);
    // Found dead, queued, and not run here: no binding return inside the
    // callback may run them.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 0), probe.?.finalizes);
    queue.leaveCallback(outer);

    // Depth zero: the next binding return runs them, in the order V8's
    // first pass found them dead.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 2), probe.?.finalizes);
    try testing.expectEqual(probe.?.unlink_order[0], probe.?.order[0]);
    try testing.expectEqual(probe.?.unlink_order[1], probe.?.order[1]);
    try testing.expectEqual(@as(u32, 0), probe.?.depths[0]);
}

test "at depth zero the report drains as before: a binding return and a checkpoint run what V8 found dead, in its first pass's order" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    const page = try Page.open(&queue, &memory);
    defer page.close();
    try page.callBinding();
    const context = contextOf(page.realm);

    probe = .{ .isolate = page.isolate(), .queue = &queue };
    defer probe = null;
    for (0..3) |_| try probe.?.arm(context);

    // The binding return: reports, and what its collections found dead runs
    // there, oldest found first - at depth zero.
    const collected = try reportUntilCollected(page, 800);
    try testing.expect(collected);
    // The collection may have finished after the last binding's return, in
    // that script: the next return runs what it queued.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 3), probe.?.finalizes);
    for (0..3) |i| {
        try testing.expectEqual(probe.?.unlink_order[i], probe.?.order[i]);
        try testing.expectEqual(@as(u32, 0), probe.?.depths[i]);
    }

    // The checkpoint: a collection with no safe point after it queues three
    // more; the checkpoint's report is due, and its drain runs them.
    for (3..6) |_| try probe.?.arm(context);
    {
        const entered = Entered.of(page.isolate());
        defer entered.leave();
        ffi.v8_Debug_CollectHoldingFinalizers(page.isolate());
    }
    try testing.expectEqual(@as(usize, 3), probe.?.finalizes);
    memory.add(1 << 20);
    try protocol.performMicrotaskCheckpoint(page.agent);
    try testing.expectEqual(@as(usize, 6), probe.?.finalizes);
    for (3..6) |i| try testing.expectEqual(probe.?.unlink_order[i], probe.?.order[i]);
}
