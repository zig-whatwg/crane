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
    /// Engine work every finalizer does: it invokes this function of the
    /// page's global as a native algorithm invokes a callback.
    callback: ?[]const u8 = null,
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
        if (self.callback) |name| invokeNamed(self.page, name) catch {
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

// The same, counted: ONE collection of V8's own - a scavenge an allocation
// started - finds three wrappers dead, no other collection follows and
// nothing pumps. V8 hands a dead wrapper to its embedder in the collection's
// FIRST pass (include/v8-weak-callback-info.h: the callback resets the
// handle, and "should additional work be required, the embedder must set a
// second pass callback" - work that needs V8's API, which the pass forbids).
// The adapter's work there is its own queue, so the first pass queues the
// finalizer and the script's next binding exit runs it. Queued by V8's second
// pass instead - a task V8 posts (15.7.112.43 src/handles/global-handles.cc:
// 892-901) that a script without a pump never reaches - they waited for the
// script's NEXT collection, which runs a pending pass first (src/heap/
// heap.cc:1509-1511): every dead wrapper kept its native state for one more
// whole young generation. dom.event-ctor, 650,000 dropped Events: 113.5 MB of
// Event state held at its end mark, 66.8 MB with the first pass queueing
// (lane v8up b7, release consoles on chat.local).
test "wrappers one collection of V8's own found dead are finalized at the script's next binding exit, with no second collection and no pump" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    probe = .{ .page = page };
    const self = &probe.?;
    for (0..3) |_| try self.arm();

    // Script that allocates and calls no binding, a piece at a time, until
    // V8's young generation fills and V8 collects by itself. A piece is far
    // smaller than a semispace (15.7: 1 MB at least, heap.cc:4945-4949), so
    // the piece that unlinks the three ran one collection, and the loop ends
    // there.
    var pieces: usize = 0;
    while (self.unlinks < 3 and pieces < 4096) : (pieces += 1) {
        try page.run("{ let junk; for (let i = 0; i < 4096; i++) junk = { i }; globalThis.junk = junk; }");
    }
    if (self.unlinks != 3 or page.queued() != 3) {
        std.debug.print("after {d} pieces of script: {d} of 3 unlinked by V8's first pass, {d} finalizers queued, {d} run\n", .{ pieces, self.unlinks, page.queued(), self.finalizes });
    }
    try testing.expectEqual(@as(usize, 3), self.unlinks);
    // Nothing of Zig's ran inside the collection, and its first pass queued
    // the three: no task of V8's and no later collection is needed.
    try testing.expectEqual(@as(usize, 0), self.finalizes);
    try testing.expectEqual(@as(usize, 3), page.queued());

    // The script's next binding exit is their safe point.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 3), self.finalizes);
    try testing.expectEqualSlices(u32, &.{ 0, 0, 0 }, self.depths[0..3]);
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
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

// Re-entrancy, first half: not under a DOM algorithm. A binding that returns
// into script while another DOM algorithm is on the stack below it - here
// one the test enters, as a binding does whose conversion runs script -
// returns at depth one, and that algorithm's own return runs nothing. These
// finalizers wait for the outermost exit, and every one of them runs at
// depth zero. (The one thing that may run at a non-zero depth is the
// finalizer of an object made since the innermost CALLBACK began - "Inside
// a callback", below; an object armed by the test is never that.)
test "a finalizer that is not fresh never runs at a non-zero DOM-algorithm depth: it waits for the outermost binding exit" {
    defer probe = null;
    defer test_agent.close();
    const page = try Page.open();
    try page.callBinding();
    const self = try queueFinalizers(page, 3);

    // A DOM algorithm is on the stack and script runs under it; the
    // script's bindings return at depth one.
    page.queue.enterAlgorithm();
    try page.callBinding();
    try page.callBinding();
    try testing.expectEqual(@as(usize, 0), self.finalizes);
    try testing.expectEqual(@as(usize, 3), page.queued());
    // That algorithm returns: nothing runs.
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

// ============================================================================
// Inside a callback: fresh by construction
// ============================================================================
//
// Script a native algorithm calls - a timer callback, an event listener, an
// observer - runs with that algorithm on the stack for the whole callback
// (the adapter counts the invocation on the queue's depth), so its bindings
// never return at depth zero, and most of a page's script runs there. The
// same 300,000-Event loop inside a listener ended at 388 MB instead of
// 168 MB, and stayed at 373 MB after two forced collections.
//
// What may run at a binding's return into a callback's script: ONLY the
// finalizer of an object a script-called constructor made (`new X()`: the
// instance created, and first wrapped, inside that one binding call) AFTER
// the innermost callback invocation still on the stack began. Every DOM
// algorithm on the stack has been suspended in its call into script since
// before such an object existed, so none holds a pointer to it. Everything
// else - an object made before the innermost callback began, a node, what an
// operation returned, the other kinds of finalizer - waits for depth zero
// as before; and nothing runs at an exit with a binding between it and the
// callback (script a conversion ran: the binding is on the stack too).
//
// The scripts tell the test what they see through built-in functions of the
// realm's global (they are not bindings: their return is no safe point):
// watch(k, object) remembers a platform object's instance, collect() runs a
// collection of V8's own (both passes, no safe point after), and mark(m)
// records which watched instances are still there.

const Watch = struct {
    const max = 8;
    const max_marks = 8;
    page: Page,
    instances: [max]?*runtime.Instance = @splat(null),
    generations: [max]u64 = @splat(0),
    /// marks[m][k]: watched object k's instance was still there at mark(m).
    marks: [max_marks][max]bool = @splat(@splat(false)),
    marked: [max_marks]bool = @splat(false),
    failed: bool = false,

    fn alive(self: *const Watch, k: usize) bool {
        const instance = self.instances[k] orelse return false;
        return runtime.SlabAllocator.generationOf(instance) == self.generations[k];
    }

    fn index(value: runtime.JSValue, limit: usize) ?usize {
        if (value != .number or value.number < 0) return null;
        const k: usize = @intFromFloat(value.number);
        return if (k < limit) k else null;
    }

    /// watch(k, object)
    fn watchSteps(_: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self = &watch.?;
        const k = (if (args.len == 2) index(args[0], max) else null) orelse {
            self.failed = true;
            return .undefined;
        };
        const instance = protocol.convertToPlatformObject(self.page.realm, args[1]) orelse {
            self.failed = true;
            return .undefined;
        };
        self.instances[k] = instance;
        self.generations[k] = runtime.SlabAllocator.generationOf(instance);
        return .undefined;
    }

    /// mark(m)
    fn markSteps(_: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self = &watch.?;
        const m = (if (args.len == 1) index(args[0], max_marks) else null) orelse {
            self.failed = true;
            return .undefined;
        };
        for (&self.marks[m], 0..) |*there, k| there.* = self.alive(k);
        self.marked[m] = true;
        return .undefined;
    }

    /// collect()
    fn collectSteps(_: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        ffi.v8_Debug_CollectHoldingFinalizers(watch.?.page.isolate);
        return .undefined;
    }

    /// Watched objects `ks` at mark `m`, as a string of one letter each:
    /// 'a' alive, 'f' freed.
    fn at(self: *const Watch, m: usize, comptime ks: []const usize) ![ks.len]u8 {
        if (!self.marked[m]) return error.MarkNotReached;
        var out: [ks.len]u8 = undefined;
        for (ks, 0..) |k, i| out[i] = if (self.marks[m][k]) 'a' else 'f';
        return out;
    }
};
var watch: ?Watch = null;
var watch_function: runtime.BuiltinFunction = .{ .steps = Watch.watchSteps, .data = null };
var mark_function: runtime.BuiltinFunction = .{ .steps = Watch.markSteps, .data = null };
var collect_function: runtime.BuiltinFunction = .{ .steps = Watch.collectSteps, .data = null };

/// What every callback script here starts from: `make(k)` makes an Event with
/// a script-called constructor, has it watched and drops it (its frame is
/// gone when it returns); `exit()` calls one binding, whose return into the
/// script is the safe point under test.
const callback_prelude =
    \\globalThis.kept = new Event('kept');
    \\function make(k) { watch(k, new Event('made')); }
    \\function exit() { void kept.type; }
;

/// A page whose scripts can watch, collect and mark.
fn openWatched() !Page {
    const page = try Page.open();
    watch = .{ .page = page };
    try protocol.defineBuiltinFunction(page.realm, "watch", 2, &watch_function);
    try protocol.defineBuiltinFunction(page.realm, "mark", 1, &mark_function);
    try protocol.defineBuiltinFunction(page.realm, "collect", 0, &collect_function);
    try page.run(callback_prelude);
    return page;
}

/// Invoke `globalThis[name]` as a native algorithm invokes a callback
/// (engine.invokeCallbackFunction, which the adapter counts): the test is
/// the native algorithm. When it returns, the callback has returned into
/// native code - which runs nothing - and no binding has returned at depth
/// zero since.
fn invoke(page: Page, comptime name: []const u8) !void {
    return invokeNamed(page, name);
}

fn invokeNamed(page: Page, name: []const u8) !void {
    var source_buffer: [64]u8 = undefined;
    const source = try std.fmt.bufPrint(&source_buffer, "globalThis.{s}", .{name});
    const function = try protocol.evaluateClassicScript(page.realm, .{ .utf8 = source }, "", null, Ignored.reporter);
    defer function.release();
    const callback: protocol.CallbackFunction = .{ .function = .{ .value = function.value }, .context = page.realm };
    const completion = try protocol.invokeCallbackFunction(page.realm, &callback, .undefined, &.{}, .rethrow);
    switch (completion) {
        .normal => |value| value.release(),
        .throw => |value| {
            value.release();
            return error.CallbackThrew;
        },
    }
}

// The shape the depth-zero exit does not reach: the same loop, inside a
// callback. The test invokes it; when the callback has returned, no binding
// has returned at depth zero, so whatever was freed was freed inside it.
test "wrappers a callback's script makes and drops are finalized inside the callback" {
    defer watch = null;
    defer test_agent.close();
    const page = try openWatched();
    try page.run("globalThis.work = function () { for (let i = 0; i < 300000; i++) new Event('x'); };");
    const scope = test_agent.own_scope.?;
    const freed_before = scope.slab.stats().total_freed;
    const made_before = scope.slab.stats().total_allocated;

    try invoke(page, "work");

    const made = scope.slab.stats().total_allocated - made_before;
    const freed = scope.slab.stats().total_freed - freed_before;
    const waiting = page.queued();
    if (freed == 0 or waiting != 0) {
        std.debug.print("300,000 Events dropped in one callback: {d} instances made, {d} freed inside it, {d} finalizers queued when it returned\n", .{ made, freed, waiting });
    }
    try testing.expect(made >= 300_000);
    try testing.expect(freed != 0);
    try testing.expectEqual(@as(usize, 0), waiting);
}

// The stamp is compared with the INNERMOST callback on the stack. Three
// levels: the callback the test invokes, a listener its script dispatches to
// (dispatchEvent's algorithm suspended below it, still using its event), and
// a listener that one dispatches to.
//   0  made at level 1                      - not inside level 2 or 3; at level 1 again, yes
//   1  made at level 2                      - inside level 2
//   2  made at level 3                      - inside level 3
//   3  made at level 2 before level 3 began - NOT inside level 3, though it is newer than
//      both outer callbacks; back at level 2, yes
// And dispatchEvent, whose listener ran all that, still reads its event when
// the listener has returned.
test "inside nested callbacks only objects made since the innermost began are finalized, and the outer algorithm still uses its arguments" {
    defer watch = null;
    defer test_agent.close();
    const page = try openWatched();
    try page.run(
        \\globalThis.outer = function () {
        \\  make(0);
        \\  const target = new EventTarget();
        \\  target.addEventListener('level2', function (event) {
        \\    make(1);
        \\    collect(); exit();
        \\    mark(0);
        \\    const inner = new EventTarget();
        \\    inner.addEventListener('level3', function () {
        \\      make(2);
        \\      collect(); exit();
        \\      mark(1);
        \\    });
        \\    make(3);
        \\    inner.dispatchEvent(new Event('level3'));
        \\    mark(2);
        \\    event.preventDefault();
        \\  });
        \\  const event = new Event('level2', { cancelable: true });
        \\  const delivered = target.dispatchEvent(event);
        \\  mark(3);
        \\  globalThis.outcome = [delivered, event.defaultPrevented, event.target === target, event.eventPhase].join();
        \\};
    );
    try invoke(page, "outer");
    const seen = &watch.?;
    try testing.expect(!seen.failed);
    // Level 2, after its own collection and exit: 0 is older than this
    // callback and waits; 1 is fresh and gone.
    try testing.expectEqualStrings("af", &try seen.at(0, &.{ 0, 1 }));
    // Level 3: 2 is fresh; 0 and 3 are older than this callback.
    try testing.expectEqualStrings("afa", &try seen.at(1, &.{ 0, 2, 3 }));
    // Back at level 2 (the inner dispatchEvent returned into it): 3 is fresh
    // here; 0 still waits for level 1.
    try testing.expectEqualStrings("af", &try seen.at(2, &.{ 0, 3 }));
    // Back at level 1 (the outer dispatchEvent returned into it): 0.
    try testing.expectEqualStrings("f", &try seen.at(3, &.{0}));
    // The outer algorithm used its event and target after the listener:
    // not delivered (cancelled), the event's own state as dispatch left it.
    try page.expectEval("globalThis.outcome", "false,true,true,0");
    // Depth zero: whatever else those collections found runs now.
    try page.callBinding();
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
}

// "Made by a script-called constructor" when the constructor itself runs
// script. An init dictionary's getter runs INSIDE the constructor's binding,
// before the instance exists: the constructor is a DOM algorithm on the stack
// below that script, so nothing is finalized at its exits - not even what
// the callback made earlier. When the constructor has returned, the object it
// made is as fresh as any other. A subclass's constructor is script: the
// object is made and wrapped inside its super() call, and is in use (`this`)
// until the subclass's constructor returns. A node is never fresh: its
// wrapper's end only lets its reference go, and its tree is freed by the
// queue at depth zero.
test "a constructor that runs script: nothing is finalized under it, and what it made is fresh once it has returned" {
    defer watch = null;
    defer test_agent.close();
    const page = try openWatched();
    try page.run(
        \\function build() {
        \\  const event = new Event('x', { get bubbles() {
        \\    make(1);
        \\    collect(); exit();
        \\    mark(0);
        \\    return true;
        \\  } });
        \\  watch(2, event);
        \\  return event.bubbles;
        \\}
        \\class Sub extends Event {
        \\  constructor() {
        \\    super('sub');
        \\    watch(3, this);
        \\    collect(); exit();
        \\    mark(3);
        \\  }
        \\}
        \\function sub() { new Sub(); }
        \\function node() { watch(4, new Document()); }
        \\globalThis.constructors = function () {
        \\  make(0);
        \\  globalThis.bubbles = build();
        \\  mark(1);
        \\  collect(); exit();
        \\  mark(2);
        \\  sub();
        \\  collect(); exit();
        \\  mark(4);
        \\  node();
        \\  collect(); exit();
        \\  mark(5);
        \\};
    );
    try invoke(page, "constructors");
    const seen = &watch.?;
    try testing.expect(!seen.failed);
    try page.expectEval("String(globalThis.bubbles)", "true");
    // Inside the getter, under the Event constructor: 0 (made by the
    // callback before) and 1 (made by the getter) both wait.
    try testing.expectEqualStrings("aa", &try seen.at(0, &.{ 0, 1 }));
    // The constructor returned into the callback's script: both are gone.
    try testing.expectEqualStrings("ff", &try seen.at(1, &.{ 0, 1 }));
    // The Event that constructor made, dropped and collected: fresh.
    try testing.expectEqualStrings("f", &try seen.at(2, &.{2}));
    // The subclass's object inside its own constructor: in use.
    try testing.expectEqualStrings("a", &try seen.at(3, &.{3}));
    // Dropped and collected: fresh.
    try testing.expectEqualStrings("f", &try seen.at(4, &.{3}));
    // A node: its teardown is the queue's, at depth zero.
    try testing.expectEqualStrings("a", &try seen.at(5, &.{4}));
    try page.callBinding();
    page.queue.drainAll();
    try testing.expect(!seen.alive(4));
}

// The two rules of the depth-zero exit hold at a callback's exits too: a
// binding that throws keeps its exception (no finalizer runs at its exit),
// and nothing runs beneath a finalizer that is on the stack - here one the
// pump is running, which calls script through a callback.
test "at a callback's exits too: a throwing binding keeps its exception, and nothing runs beneath a running finalizer" {
    defer probe = null;
    defer watch = null;
    defer test_agent.close();
    const page = try openWatched();
    try page.run(
        \\globalThis.throws = function () {
        \\  make(0);
        \\  collect();
        \\  globalThis.caught = 'nothing';
        \\  try { new Event(); globalThis.caught = 'no exception'; } catch (e) { globalThis.caught = e.name; }
        \\  mark(0);
        \\  exit();
        \\  mark(1);
        \\};
        \\globalThis.beneath = function () {
        \\  make(1);
        \\  collect(); exit();
        \\  mark(2);
        \\};
    );
    try invoke(page, "throws");
    const seen = &watch.?;
    try testing.expect(!seen.failed);
    try page.expectEval("globalThis.caught", "TypeError");
    try testing.expectEqualStrings("a", &try seen.at(0, &.{0}));
    try testing.expectEqualStrings("f", &try seen.at(1, &.{0}));

    // A finalizer the pump runs invokes a callback, as a native teardown may.
    const self = try queueFinalizers(page, 1);
    self.callback = "beneath";
    try testing.expect(ffi.v8_Platform_PumpMessageLoop(page.isolate));
    try testing.expectEqual(@as(usize, 1), self.finalizes);
    try testing.expect(!self.failed);
    // Inside that callback the fresh object waited: a drain was on the stack.
    try testing.expectEqualStrings("a", &try seen.at(2, &.{1}));
    // The drain that was running took it when the finalizer returned.
    try testing.expect(!seen.alive(1));
    try testing.expectEqual(@as(usize, 0), page.queued());
    try testing.expectEqual(@as(u8, 0), page.owed());
}

// The callback clock is 32 bits. When it can tick no more, nothing made from
// then on is fresh: the objects of a callback wait for depth zero, as every
// object did before - never the other way round. (A stamp is the clock's
// value and the clock's last value stamps nothing, so a stamp can never
// equal the tick every later callback shares.)
test "a saturated callback clock makes nothing fresh" {
    if (!@hasField(DeferredTeardown, "callback")) return error.SkipZigTest;
    defer watch = null;
    defer test_agent.close();
    const page = try openWatched();
    try page.run("globalThis.late = function () { make(0); collect(); exit(); mark(0); };");
    const last = std.math.maxInt(u32);
    page.queue.callback.serial = last - 2;
    // One tick before the last: this callback's objects are still fresh.
    try invoke(page, "late");
    const seen = &watch.?;
    try testing.expectEqual(@as(u32, last - 1), page.queue.callback.serial);
    try testing.expectEqualStrings("f", &try seen.at(0, &.{0}));
    // The last tick, and no tick after it: the same callback's objects wait.
    try invoke(page, "late");
    try testing.expectEqual(@as(u32, last), page.queue.callback.serial);
    try testing.expectEqualStrings("a", &try seen.at(0, &.{0}));
    try invoke(page, "late");
    try testing.expectEqual(@as(u32, last), page.queue.callback.serial);
    try testing.expectEqualStrings("a", &try seen.at(0, &.{0}));
    try testing.expect(!seen.failed);
    // Depth zero frees them.
    try page.callBinding();
    try testing.expect(!seen.alive(0));
    try testing.expectEqual(@as(usize, 0), page.queued());
}
