//! The binding exit back into script is the agent's safe point for the
//! finalizers of its collected wrappers INSIDE a task (lane v8up b6c).
//!
//! V8's second pass runs no Zig finalizer: it only queues the record on its
//! agent (v8_wrapper.cpp `queueFinalizer`; 15.7 runs the pass under
//! DisallowJSObjectModification), and the agent runs it at a safe point. The
//! pump and a forced collection's return are safe points BETWEEN tasks. One
//! long script reaches neither: a collection V8 runs by itself posts its
//! second pass as a task (15.7.112.43 src/handles/global-handles.cc:892-901),
//! the next collection runs that pending pass first (src/heap/heap.cc:
//! 1509-1511), and so every wrapper the script dropped waited, queued, with
//! its native state, for the task's end - 300,000 dropped Events in one loop
//! ended at 392 MB instead of 168 MB.
//!
//! The safe point such a script does reach is a binding's return into it at
//! DOM-algorithm depth zero (dom_algorithm.zig leaveToScript ->
//! runtime.gc.DeferredTeardown.leaveAlgorithmToScript): the second pass sets
//! one bit of what the agent's queue owes, and the exit that finds it runs
//! the queued finalizers before anything else it owes. Blink's wrappables
//! are cppgc objects whose destructors run when an allocation sweeps their
//! page, inside the running script (cppgc-internal/object-allocator.cc
//! TryRefillLinearAllocationBuffer -> Sweeper::SweepForAllocationIfRunning).
//!
//! The armed objects here are plain objects of the test agent's own context
//! with a finalizer of the test's (v8_Global_SetWeakFinalizer, as the wrapper
//! cache arms a wrapper); the collections that queue them are V8's own
//! (v8_Debug_CollectHoldingFinalizers: both passes inside the collection, no
//! safe point after it); the bindings are a Window realm's.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;

/// The test's own agent, ended with the test (test_process.TestAgent).
var test_agent: test_process.TestAgent = .{};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

/// The test agent with a Window realm: scripts run in the realm, and their
/// binding calls return into them at DOM-algorithm depth zero.
const Page = struct {
    isolate: *ffi.Isolate,
    /// The agent's own bootstrap context, entered: where the armed objects
    /// and the object their finalizers write to are made.
    context: *ffi.Context,
    realm: runtime.Context,
    /// The agent's deferred teardown queue (its own: the test gives none),
    /// whose depth the bindings count on and whose owed word the second
    /// pass sets a bit of.
    queue: *DeferredTeardown,

    fn open() !Page {
        const isolate = try test_agent.open(.{});
        const realm = try test_agent.windowRealm(&.{
            .agent = test_agent.agent(),
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        const queue = protocol.deferredTeardownOf(test_agent.agent()) orelse return error.NoQueue;
        const page: Page = .{ .isolate = isolate, .context = test_agent.context.?, .realm = realm, .queue = queue };
        // Nothing of the realm's creation is under way or queued.
        ffi.v8_Isolate_RequestGarbageCollection(isolate);
        while (ffi.v8_Platform_PumpMessageLoop(isolate)) {}
        return page;
    }

    fn run(self: Page, source: []const u8) !void {
        try protocol.runClassicScript(self.realm, .{ .utf8 = source }, "", null, Ignored.reporter);
    }

    fn expectEval(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, Ignored.reporter);
        defer testing.allocator.free(got);
        try testing.expectEqualStrings(expected, got);
    }

    /// A script that calls one binding - an attribute getter of an Event the
    /// page keeps - and returns: one binding exit into script.
    fn callBinding(self: Page) !void {
        try self.run("void (globalThis.kept ??= new Event('kept')).type;");
    }

    fn queued(self: Page) usize {
        return ffi.v8_Debug_QueuedFinalizers(self.isolate);
    }

    /// What the queue owes, as its one byte.
    fn owed(self: Page) u8 {
        return @bitCast(self.queue.owed);
    }
};

/// One armed object: its index and its handle, which its finalizer disposes
/// as an owner does.
const Armed = struct {
    index: u8,
    handle: ?*ffi.Object = null,
};

/// What the finalizers of a test saw and did.
const Probe = struct {
    const max = 8;
    page: Page,
    armed: [max]Armed = undefined,
    armed_count: usize = 0,
    unlinks: usize = 0,
    /// The armed objects' indexes in the order V8's first pass unlinked them.
    unlink_order: [max]u8 = @splat(0xff),
    finalizes: usize = 0,
    /// The armed objects' indexes in the order their finalizers ran.
    order: [max]u8 = @splat(0xff),
    /// The DOM-algorithm depth each finalizer ran at.
    depths: [max]u32 = @splat(0xffff),
    /// Finalizers on the stack now, and the most there ever were.
    running: usize = 0,
    most_running: usize = 0,
    /// Engine work every finalizer does: a script of the page's realm, whose
    /// binding calls return into it at depth zero - beneath the finalizer.
    script: ?[]const u8 = null,
    /// The first finalizer to run also lets one more armed object die under
    /// itself, in a collection V8 runs by itself: its second pass queues
    /// that object's finalizer and owes it, while this one is on the stack.
    collects_under_first: bool = false,
    /// What the first finalizer saw when the binding its script called had
    /// returned: finalizers run so far (itself included), and queued.
    finalizes_under_first: usize = 0,
    queued_under_first: usize = 0,
    failed: bool = false,

    fn arm(self: *Probe) !void {
        const armed = &self.armed[self.armed_count];
        armed.* = .{ .index = @intCast(self.armed_count) };
        self.armed_count += 1;
        const scope = ffi.v8_HandleScope_New(self.page.isolate);
        const object = ffi.v8_Object_New(self.page.isolate) orelse return error.ObjectCreationFailed;
        if (scope) |s| ffi.v8_HandleScope_Dispose(s);
        armed.handle = object;
        ffi.v8_Global_SetWeakFinalizer(@ptrCast(object), @ptrCast(armed), unlinked, finalized);
    }

    /// A collection V8 runs by itself, both passes inside it and no safe
    /// point after it: what it found dead is queued on the agent.
    fn collect(self: *Probe) void {
        ffi.v8_Debug_CollectHoldingFinalizers(self.page.isolate);
    }

    fn unlinked(data: ?*anyopaque, _: usize) callconv(.c) void {
        const armed: *Armed = @ptrCast(@alignCast(data.?));
        const self = &probe.?;
        self.unlink_order[self.unlinks] = armed.index;
        self.unlinks += 1;
    }

    /// The order the finalizers of the first `count` unlinked objects run
    /// in: V8's second pass takes the records from the back of the list its
    /// first pass built (15.7 src/handles/global-handles.cc:850, 765-767),
    /// and the queue keeps that order.
    fn handedOver(self: *const Probe, comptime count: usize) [count]u8 {
        var order: [count]u8 = undefined;
        for (&order, 0..) |*index, i| index.* = self.unlink_order[count - 1 - i];
        return order;
    }

    fn finalized(data: ?*anyopaque, _: usize) callconv(.c) void {
        const armed: *Armed = @ptrCast(@alignCast(data.?));
        const self = &probe.?;
        self.running += 1;
        defer self.running -= 1;
        self.most_running = @max(self.most_running, self.running);
        const nth = self.finalizes;
        self.order[nth] = armed.index;
        self.depths[nth] = self.page.queue.algorithm_depth;
        self.finalizes += 1;
        if (armed.handle) |handle| ffi.v8_Object_Dispose(handle);
        armed.handle = null;
        if (nth == 0 and self.collects_under_first) {
            self.arm() catch {
                self.failed = true;
            };
            self.collect();
        }
        if (self.script) |source| self.page.run(source) catch {
            self.failed = true;
        };
        if (nth == 0) {
            self.finalizes_under_first = self.finalizes;
            self.queued_under_first = self.page.queued();
        }
    }
};
var probe: ?Probe = null;

/// `count` armed objects, dead and queued by one collection of V8's own:
/// nothing of Zig's has run.
fn queueFinalizers(page: Page, count: usize) !*Probe {
    probe = .{ .page = page };
    const self = &probe.?;
    for (0..count) |_| try self.arm();
    self.collect();
    try testing.expectEqual(count, self.unlinks);
    try testing.expectEqual(@as(usize, 0), self.finalizes);
    try testing.expectEqual(count, page.queued());
    return self;
}

// The shape that found it: one script, 300,000 Events made and dropped, every
// iteration a binding call, never a pump, a forced collection or a report
// (an Event is not in the DOM memory figure). V8 collects by itself as its
// young generation fills; each collection hands the dead wrappers of the one
// before it to the agent's queue. The script's own binding exits are the only
// safe point it reaches.
test "wrappers a script drops while it keeps calling bindings are finalized inside that script, with no pump" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    // The scope the realm's Events are made in: what a finalized Event gives
    // back is its slab slot.
    const scope = test_agent.own_scope.?;
    const freed_before = scope.slab.stats().total_freed;
    const made_before = scope.slab.stats().total_allocated;

    try page.run("for (let i = 0; i < 300000; i++) new Event('x');");

    const made = scope.slab.stats().total_allocated - made_before;
    const freed = scope.slab.stats().total_freed - freed_before;
    const waiting = page.queued();
    if (freed == 0 or waiting != 0) {
        std.debug.print("300,000 Events dropped in one script: {d} instances made, {d} freed inside it, {d} finalizers queued at its end\n", .{ made, freed, waiting });
    }
    try testing.expect(made >= 300_000);
    // They ran inside the script, at its binding exits...
    try testing.expect(freed != 0);
    // ...each collection's as the next exit found them: none waits for the
    // pump when the script returns.
    try testing.expectEqual(@as(usize, 0), waiting);
}

test "queued finalizers run at the next binding exit into script, in the order V8's second pass handed them over, with engine work allowed" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    const self = try queueFinalizers(page, 3);
    // Each finalizer runs a script of the page that writes a new property of
    // its global and calls a binding.
    self.script = "globalThis.finalized = (globalThis.finalized || 0) + 1; void kept.type;";

    // The script keeps calling bindings: the first exit back into it is the
    // safe point.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 3), self.finalizes);
    try testing.expect(!self.failed);
    try testing.expectEqualSlices(u8, &self.handedOver(3), self.order[0..3]);
    try page.expectEval("String(globalThis.finalized)", "3");
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

// Re-entrancy, first half: never under a DOM algorithm. A binding that
// returns into script a native algorithm called (a listener, a timer or
// observer callback: the adapter counts the invocation on the queue's depth)
// returns at depth one, and a callback's return into its native caller runs
// nothing. The finalizers wait for the outermost exit, and every one of them
// runs at depth zero.
test "finalizers never run at a non-zero DOM-algorithm depth: they wait for the outermost binding exit" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    const self = try queueFinalizers(page, 3);

    // A native algorithm is on the stack and calls script (what
    // invokeCallbackFunction counts); the script's bindings return at depth
    // one.
    page.queue.enterAlgorithm();
    try page.callBinding();
    try page.callBinding();
    try testing.expectEqual(@as(usize, 0), self.finalizes);
    try testing.expectEqual(@as(usize, 3), page.queued());
    // The callback returns into the native algorithm: nothing runs.
    page.queue.leaveAlgorithmToNative();
    try testing.expectEqual(@as(usize, 0), self.finalizes);
    try testing.expectEqual(@as(usize, 3), page.queued());

    // Back at depth zero, the next binding exit runs them.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 3), self.finalizes);
    try testing.expectEqualSlices(u32, &.{ 0, 0, 0 }, self.depths[0..3]);
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
}

// Re-entrancy, second half: a finalizer the exit runs does not run another
// beneath itself. The first finalizer lets one more wrapper die under it (a
// collection V8 runs by itself queues that finalizer and owes it) and then
// runs a script whose binding returns into it at depth zero - an exit that
// finds finalizers owed. It runs none: the drain on the stack takes each
// record afresh, so what was queued under a finalizer runs after it returns.
// cppgc's sweeper does the same when a finalizer allocates (cppgc-internal/
// sweeper.cc:1197-1211, "Bail out for recursive sweeping calls").
test "a finalizer that enters and leaves a binding does not run the queue beneath itself" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    const self = try queueFinalizers(page, 3);
    self.collects_under_first = true;
    self.script = "void kept.type; void kept.bubbles;";

    try page.callBinding();
    try testing.expect(!self.failed);
    // When the first finalizer's bindings had returned, it was the only one
    // that had run, and the rest - the one queued under it included - still
    // waited.
    try testing.expectEqual(@as(usize, 1), self.finalizes_under_first);
    try testing.expectEqual(@as(usize, 3), self.queued_under_first);
    try testing.expectEqual(@as(usize, 1), self.most_running);
    // All four ran, each once, at depth zero, the one queued last last.
    try testing.expectEqual(@as(usize, 4), self.finalizes);
    try testing.expectEqualSlices(u8, &self.handedOver(3), self.order[0..3]);
    try testing.expectEqual(@as(u8, 3), self.order[3]);
    try testing.expectEqualSlices(u32, &.{ 0, 0, 0, 0 }, self.depths[0..4]);
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

// A binding that throws returns with its exception pending, and V8 hands an
// exception thrown inside an API callback only to a TryCatch registered
// before the throw: engine work a finalizer did at that exit would clear it
// silently (v8_wrapper.cpp, "Binding catch scopes"), and the script would
// never see its TypeError. The exit runs no finalizer while an exception is
// pending (Isolate::HasPendingException); they stay owed, and the next exit
// that returns normally runs them.
test "a binding that throws keeps its exception: its exit runs no finalizer, the next normal exit does" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    const self = try queueFinalizers(page, 2);
    // Engine work that runs script, as an instance's teardown may.
    self.script = "globalThis.finalized = (globalThis.finalized || 0) + 1;";

    // `new Event()` throws a TypeError (WebIDL: not enough arguments) and
    // returns into the script's catch block, which calls no binding.
    try page.run("globalThis.caught = 'nothing'; try { new Event(); globalThis.caught = 'no exception'; } catch (e) { globalThis.caught = e.name; }");
    try page.expectEval("globalThis.caught", "TypeError");
    try testing.expectEqual(@as(usize, 0), self.finalizes);
    try testing.expectEqual(@as(usize, 2), page.queued());

    // The next binding returns normally: they run there.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 2), self.finalizes);
    try testing.expect(!self.failed);
    try page.expectEval("String(globalThis.finalized)", "2");
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
}

// The pump stays a safe point, and it settles what the queue owes: a drain
// there leaves no bit behind for the next binding exit to pay for.
test "the pump runs what a second pass queued and leaves nothing owed for the next binding exit" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    const self = try queueFinalizers(page, 2);

    try testing.expect(ffi.v8_Platform_PumpMessageLoop(page.isolate));
    try testing.expectEqual(@as(usize, 2), self.finalizes);
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
}

// The agent's end: the pointer V8's second pass writes through is the
// queue's, and the agent's own queue is freed with it. The agent ends with
// finalizers queued and owed; its last forced collections run them, and no
// second pass writes to the queue after it is gone.
test "an agent that ends with finalizers owed runs them once, and its last collections owe nothing to a freed queue" {
    defer probe = null;
    const page = try Page.open();
    var closed = false;
    defer if (!closed) test_agent.close();
    try page.callBinding();
    const self = try queueFinalizers(page, 2);
    // One more, alive until the agent's last collections find it.
    try self.arm();

    test_agent.close();
    closed = true;
    try testing.expectEqual(@as(usize, 3), self.finalizes);
    for (self.armed[0..3]) |armed| try testing.expect(armed.handle == null);
}
