//! The wrapper redesign's P4 (tmp/redesign/wrapper-redesign-design.md section
//! 7, P4; 4.1-4.5, 4.8; risks R1, R4 and R8): node wrappers on the agent's
//! C++ heap.
//!
//! A node interface's template has no internal field. Its wrapper points at a
//! NodeAnchor on the agent's CppHeap through `v8::Object::Wrap`, under the
//! node anchors' CppHeapPointerTag; the anchor holds the node's slot, and the
//! slot a `TracedReference` to the wrapper - Blink's ScriptWrappable with its
//! TraceWrapperV8Reference (third_party/blink/renderer/platform/bindings/
//! script_wrappable.h). A wrapper V8's marker reaches keeps its anchor, whose
//! Trace keeps the slot; a dead anchor's slot is emptied in the collection's
//! atomic pause (the registry's weak callback), and its counted reference is
//! released after the collection, at the agent's next safe point: a
//! binding's return into script, the pump, a requested collection's end
//! (lane v8up's finalizer queue, which the collection itself owes the
//! releases to since lane wr1 b11; until then they waited where V8 runs a
//! second pass - a posted task, or the next collection's start).
//!
//! The collections are V8's own (LowMemoryNotification through the FFI). The
//! file shares tests/v8's process: it starts the engine as any file may and
//! makes its own agent per test (the snapshot test needs a process of its
//! own: tests-v8 runs at batch 1).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const DeferredTeardown = runtime.gc.DeferredTeardown;
const SlabAllocator = runtime.SlabAllocator;
const NodeBase = dom.NodeBase;

/// The snapshot this build generated (build.zig passes its path).
const snapshot_path = @import("test_snapshot").path;

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
    /// A second window realm of the same agent (`openSecondRealm`), or null.
    other: ?runtime.Context = null,
    queue: ?*DeferredTeardown,
    /// The snapshot's bytes, for a page restored from it.
    snapshot: ?[]u8 = null,

    fn realmOptions(agent: *engine.Agent, from_snapshot: bool) engine.WindowRealmOptions {
        return .{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = from_snapshot,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        };
    }

    /// An agent with `queue` as its deferred teardown queue, and one window
    /// realm, made without the snapshot.
    fn open(queue: ?*DeferredTeardown) !Page {
        test_process.start();
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &test_process.no_hooks,
            .host = null,
            .deferred_teardown = queue,
        });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&realmOptions(agent, false));
        return .{ .agent = agent, .realm = realm, .queue = queue };
    }

    /// An agent and a window realm both restored from this build's snapshot
    /// (design 4.8, R8), or null - the test skips - when V8 was started in
    /// this process before the test.
    fn openFromSnapshot(queue: *DeferredTeardown) !?Page {
        if (ffi.v8_Platform_IsInitialized()) {
            std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1; -Dlaunch-batch=1 or -Dtest-file=)", .{});
            return null;
        }
        const io = std.testing.io;
        const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        try test_process.startSnapshot(bytes);
        errdefer test_process.endSnapshot();
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = true,
            .hooks = &test_process.no_hooks,
            .host = null,
            .deferred_teardown = queue,
        });
        errdefer engine.destroyAgent(agent);
        if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        const realm = try engine.createWindowRealm(&realmOptions(agent, true));
        return .{ .agent = agent, .realm = realm, .queue = queue, .snapshot = bytes };
    }

    /// A second window realm of the page's agent: a node made there is the
    /// same agent's, with its own relevant realm.
    fn openSecondRealm(self: *Page) !void {
        self.other = try engine.createWindowRealm(&realmOptions(self.agent, false));
    }

    fn close(self: Page) void {
        if (self.other) |other| engine.destroyWindowRealm(other, .global_detached);
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
        if (self.snapshot) |bytes| {
            test_process.endSnapshot();
            std.heap.c_allocator.free(bytes);
        }
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn runIn(realm: runtime.Context, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn run(self: Page, source: []const u8) !void {
        try runIn(self.realm, source);
    }

    /// Whether `source` evaluates to true.
    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return engine.toBoolean(self.realm, held.value);
    }

    fn instanceIn(realm: runtime.Context, source: []const u8) !?*runtime.Instance {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return engine.convertToPlatformObject(realm, held.value);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        return (try instanceIn(self.realm, source)) orelse error.NotAPlatformObject;
    }

    /// A requested full collection, twice (v8_Isolate_RequestGarbageCollection:
    /// what it collected is released at its end).
    fn collect(self: Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
    }

    /// What the probe sees of the wrapper in `node`'s slot.
    fn probe(self: Page, node: *NodeBase) ffi.NodeWrapperProbe {
        const isolate_ = self.isolate();
        const enter = ffi.v8_Isolate_GetCurrent() != isolate_;
        if (enter) ffi.v8_Isolate_Enter(isolate_);
        defer if (enter) ffi.v8_Isolate_Exit(isolate_);
        var seen: ffi.NodeWrapperProbe = undefined;
        ffi.v8_test_NodeWrapper_Probe(isolate_, @ptrCast(runtime.lifetime.slotOf(node)), &seen);
        return seen;
    }
};

/// A slab slot and the generation it had: whether the object is still there.
/// Read before anything of the node is: a freed node's fields are poison.
const Watched = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Watched {
        return .{ .instance = instance, .generation = SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Watched) bool {
        return SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// A detached <div> of a Document script keeps (`globalThis.d`), wrapped
/// once (`globalThis.x`), the creator's reference adopted by that wrapper:
/// count 1. Whatever making it queued is drained.
fn detachedDiv(page: Page) !struct { div: Watched, node: *NodeBase } {
    const div = try page.instance("globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    const node = dom.instance_bridge.getNodeBase(div) orelse return error.NotANode;
    if (page.queue) |queue| queue.drainAll();
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(node));
    return .{ .div = Watched.of(div), .node = node };
}

/// The adapter's counter `name` now (engine.diagnosticCounters).
fn counter(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    std.debug.print("the adapter reports no counter named {s}\n", .{name});
    return error.CounterMissing;
}

/// `counter`, read with the page's isolate entered (the C++ heap's bytes are
/// the current isolate's).
fn counterOf(page: Page, name: []const u8) !i64 {
    const isolate = page.isolate();
    const enter = ffi.v8_Isolate_GetCurrent() != isolate;
    if (enter) ffi.v8_Isolate_Enter(isolate);
    defer if (enter) ffi.v8_Isolate_Exit(isolate);
    return counter(name);
}

fn expectAnchoredWrapper(page: Page, node: *NodeBase) !void {
    const seen = page.probe(node);
    try testing.expect(seen.has_wrapper);
    // A JS_API_OBJECT with no internal field (design 4.1: 12 + 4 = 16 bytes,
    // against 32 with two fields).
    try testing.expect(seen.api_wrapper);
    try testing.expectEqual(@as(i32, 0), seen.internal_fields);
    // Object::Unwrap under the node anchors' tag finds its anchor, which
    // holds this node's slot.
    try testing.expect(seen.anchor != null);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(runtime.lifetime.slotOf(node))), seen.anchor_slot);
}

test "a node wrapper has no internal field, and Object::Unwrap yields the anchor that holds its node's slot" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    try expectAnchoredWrapper(page, made.node);
    // Every kind of node: a Text, a Comment, a DocumentFragment, the
    // Document itself (a constructor's: `new Document()`, whose receiver
    // the binding binds - interface.setInstance writes no field for a
    // node), an element and a document made by the parser. (A Text's or a
    // DocumentFragment's constructor needs the global's document, which
    // this bare realm has not: tests/html and the A/B cover them.)
    const kinds = [_][]const u8{
        "d.createTextNode('t')",
        "d.createComment('c')",
        "d.createDocumentFragment()",
        "d",
        "new DOMParser().parseFromString('<p><b>x</b></p>', 'text/html').body.firstChild",
        "new DOMParser().parseFromString('<p></p>', 'text/html')",
    };
    try page.run("globalThis.kept = [];");
    for (kinds) |source| {
        var buffer: [256]u8 = undefined;
        const kept = try std.fmt.bufPrint(&buffer, "(() => {{ const n = {s}; kept.push(n); return n; }})()", .{source});
        const node_instance = page.instance(kept) catch |err| {
            std.debug.print("making {s} failed\n", .{source});
            return err;
        };
        const node = dom.instance_bridge.getNodeBase(node_instance) orelse return error.NotANode;
        try expectAnchoredWrapper(page, node);
    }
    // Unwrapped by the binding through its anchor: a node interface's
    // members, an argument, an interceptor's holder, the brand check.
    try testing.expect(try page.holds("x.localName === 'div' && kept[0].data === 't' && kept[3].body === null"));
    try testing.expect(try page.holds("(() => { const f = d.createDocumentFragment(); f.appendChild(x); return f.firstChild === x && x.parentNode === f; })()"));
    try testing.expect(try page.holds("(() => { try { HTMLElement.prototype.click.call(kept[0]); return false; } catch (e) { return e instanceof TypeError; } })()"));
}

test "R8: a node wrapper made after the snapshot's deserialization has no internal field and a CppHeap pointer" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = (try Page.openFromSnapshot(&queue)) orelse return;
    defer page.close();
    const made = try detachedDiv(page);
    try expectAnchoredWrapper(page, made.node);
    // A parsed tree's element, and its document.
    const body = try page.instance("globalThis.parsed = new DOMParser().parseFromString('<p>x</p>', 'text/html'); parsed.body");
    try expectAnchoredWrapper(page, dom.instance_bridge.getNodeBase(body) orelse return error.NotANode);
    const parsed = try page.instance("parsed");
    try expectAnchoredWrapper(page, dom.instance_bridge.getNodeBase(parsed) orelse return error.NotANode);
    try testing.expect(try page.holds("x.localName === 'div' && parsed.body.firstChild.localName === 'p' && parsed.body.ownerDocument === parsed"));
}

/// What the epilogue probe saw of the watched node, at the end of the full
/// collections it watched.
const EpilogueWatch = struct {
    /// Set once the node is made (the probe is installed before).
    node: ?*NodeBase = null,
    div: Watched = undefined,
    collections: u32 = 0,
    /// At the first collection that found the slot empty: the count then.
    count_when_emptied: ?u32 = null,

    fn seen(data: ?*anyopaque) callconv(.c) void {
        const self: *EpilogueWatch = @ptrCast(@alignCast(data.?));
        const node = self.node orelse return;
        self.collections += 1;
        if (self.count_when_emptied != null or !self.div.alive()) return;
        if (!runtime.lifetime.slotOf(node).isEmpty()) return;
        self.count_when_emptied = dom.refcount.count(node);
    }
};

test "the anchor registry grows geometrically: a node wrap does not copy it" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    try page.run("globalThis.many = []; for (let i = 0; i < 3000; i++) many.push(d.createElement('p'));");
    const seen = page.probe(made.node);
    try testing.expect(seen.registered_anchors >= 3001);
    // Room ahead of the anchors, by doubling: an exact reserve(size + 1) per
    // wrap - every wrap copying the whole vector, quadratic in the live
    // anchors (83f1e0e187b: the perf pair's create-element ran 9.6x) - left
    // the capacity equal to the size after every wrap.
    try testing.expect(seen.anchor_capacity > seen.registered_anchors);
    try testing.expect(std.math.isPowerOfTwo(seen.anchor_capacity));
    try page.run("globalThis.many = null;");
    page.collect();
}

test "a dropped wrapper's slot is empty when the GC epilogue runs, and its count is released after" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    // The probe first: V8 calls epilogue callbacks in the order they were
    // added (13.1 src/heap/gc-callbacks.h), and the agent's own - which
    // drains a forced collection's releases at its end, as V8 runs a forced
    // collection's second passes - is added with the agent's first node wrap.
    var watch: EpilogueWatch = .{};
    const probe = ffi.v8_test_FullGCEpilogueProbe_New(page.isolate(), EpilogueWatch.seen, &watch);
    defer ffi.v8_test_FullGCEpilogueProbe_Delete(probe);
    const made = try detachedDiv(page);
    watch.node = made.node;
    watch.div = made.div;

    try page.run("globalThis.x = null;");
    page.collect();
    try testing.expect(watch.collections >= 1);
    // Emptied in the collection's atomic pause (the anchor registry's weak
    // processing), before any epilogue: the wrapper's reference was still
    // held then - the counts move only after the collection.
    try testing.expectEqual(@as(?u32, 1), watch.count_when_emptied);
    // Released at the requested collection's end: the tree's last hold, so
    // it is queued - never freed by the collector.
    try testing.expect(made.div.alive());
    try testing.expectEqual(@as(u32, 0), dom.refcount.count(made.node));
    try testing.expectEqual(@as(usize, 1), queue.len());
    queue.drainAll();
    try testing.expect(!made.div.alive());
}

test "=== holds across collections while script holds the node" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(
        \\globalThis.d = new Document();
        \\globalThis.p = d.createElement('p');
        \\p.appendChild(d.createElement('span')).expando = 5;
        \\globalThis.held = d.createElement('i');
        \\held.expando = 6;
        \\p.appendChild(held);
        \\globalThis.loose = d.createTextNode('loose');
        \\loose.expando = 7;
    );
    for (0..3) |_| {
        page.collect();
        queue.drainAll();
    }
    // Held by script: the same wrapper by every path that hands it back.
    try testing.expect(try page.holds("held === p.lastChild && held === p.querySelector('i') && held.expando === 6"));
    try testing.expect(try page.holds("loose.expando === 7 && loose === loose.cloneNode().ownerDocument.createTreeWalker(loose).root"));
    // Reached only through a held tree (the JS tree edges carry it in P4):
    // its wrapper, and its expando, survive.
    try testing.expect(try page.holds("p.firstChild.expando === 5 && p.firstChild === p.firstElementChild"));
    // Moved to another tree: still one wrapper.
    try testing.expect(try page.holds("(() => { globalThis.d2 = new Document(); d2.appendChild(held); return held.parentNode === d2 && held.expando === 6; })()"));
    page.collect();
    try testing.expect(try page.holds("held.expando === 6 && d2.documentElement === held && held.ownerDocument === d2"));
}

test "a node anchor is 32 bytes of its agent's C++ heap, and a node wrapper keeps no Global" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document(); globalThis.xs = [];");
    page.collect();
    queue.drainAll();
    const cpp_before = try counterOf(page, "cpp_heap_used_bytes");
    const globals_before = try counter("live_object_globals");
    const wrappers_before = try counter("node_wrappers");
    const count = 1000;
    // Made and kept through a LOCAL array, then stored: a hot loop over a
    // global (`xs.push` 1,000 times: on-stack replacement) makes V8 compile
    // it concurrently, and the compile job's canonical persistent handles
    // hold what it read - the global's value, the array and its 1,000
    // wrappers - until the job is disposed; a collection does not wait for a
    // running job (13.1 Heap::CollectAllAvailableGarbage:
    // AbortConcurrentOptimization(kDontBlock)). `xs = null` then left the
    // wrappers reachable through both requested collections, 1 batched run in
    // about 60: weak processing ran in each and found no anchor dead, a later
    // collection found all 1,000, and a heap snapshot taken at such a moment
    // shows the path (GC roots) -> (Handle scope) -> Array -> Element, the
    // handle-scope root holding the job's FeedbackVector, BytecodeArray,
    // LoadHandlers, PropertyCells and Maps (V8 reports PersistentHandles
    // there). V8-internal and test-only: the wrappers go at the next
    // collection after the job ends. With the array local, 0 failures in 25
    // verify runs (250 batched, 125 alone).
    try page.run("globalThis.xs = (() => { const a = []; for (let i = 0; i < 1000; i++) a.push(d.createElement('div')); return a; })();");
    page.collect();
    queue.drainAll();
    try testing.expectEqual(wrappers_before + count, try counter("node_wrappers"));
    // One anchor each: cppgc's 8-byte header, the vptr every
    // v8::Object::Wrappable has (V8 15.7's Object::Wrap takes one; 13.1.203
    // took any cppgc object and the anchor was 24 bytes), the slot pointer
    // (design 4.1) and its registry index with its keeps' count (4 + 4
    // bytes: the O(1) removal when a scavenge drops its wrapper and the
    // anchor is freed, lane wr1 batch 8). The registry holds raw pointers,
    // off the C++ heap.
    const per_node = @divTrunc(try counterOf(page, "cpp_heap_used_bytes") - cpp_before, count);
    try testing.expectEqual(@as(i64, 32), per_node);
    // No Global<Object> per node: the binding's box went once the slot held
    // the wrapper (P2 kept its node in the slot).
    try testing.expect(try counter("live_object_globals") - globals_before < 10);
    // And they go again.
    try page.run("globalThis.xs = null;");
    page.collect();
    try testing.expectEqual(wrappers_before, try counter("node_wrappers"));
}

test "an agent that ends with a collection's releases still owed: its end releases what the safe point would have" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var watched: Watched = undefined;
    {
        const page = try Page.open(&queue);
        defer page.close();
        const made = try detachedDiv(page);
        watched = made.div;
        try page.run("globalThis.x = null;");
        // A full collection with no safe point after it - as one V8 runs by
        // itself in the middle of a script: the slot is emptied in its
        // pause, and the wrapper's reference waits for the agent's next safe
        // point.
        {
            const isolate = page.isolate();
            ffi.v8_Isolate_Enter(isolate);
            defer ffi.v8_Isolate_Exit(isolate);
            ffi.v8_test_Isolate_CollectWithoutDrain(isolate);
        }
        try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
        try testing.expect(made.div.alive());
        try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));
        try testing.expect(queue.isEmpty());
        // The page ends with it still owed: no script ran, nothing pumped.
    }
    // The realm's and the agent's ends released the reference and freed the
    // tree.
    try testing.expect(!watched.alive());
    try testing.expect(queue.isEmpty());
}

test "wrappers a collection of V8's own found dead are released at the next binding's return into script: no task, no pump, no later collection" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    const isolate = page.isolate();
    // wrapper-churn-nogc's shape: elements made and dropped at once, script
    // allocating until V8 runs a collection of its own - since P8 a
    // scavenge, which drops the unmodified wrappers. Looked for: a script in
    // which exactly ONE collection ran. (Until lane wr1 b11 its releases
    // waited for a posted task or for the next collection's start, so a
    // script with two collections released the first one's either way.)
    var proved = false;
    var rounds: usize = 0;
    while (rounds < 80 and !proved) : (rounds += 1) {
        // From a settled agent: nothing owed, nothing queued.
        ffi.v8_Isolate_Enter(isolate);
        while (ffi.v8_Platform_PumpMessageLoop(isolate)) {}
        ffi.v8_Isolate_Exit(isolate);
        queue.drainAll();
        const collections = try counterOf(page, "full_gc_count") + try counterOf(page, "minor_gc_count");
        const queued = queue.queued_total;
        try page.run("{ for (let i = 0; i < 20000; i++) d.createElement('div'); const junk = []; for (let i = 0; i < 20000; i++) junk.push({ i, s: 'x' + i }); }");
        if (try counterOf(page, "full_gc_count") + try counterOf(page, "minor_gc_count") != collections + 1) continue;
        // One more binding call returns into script: the agent's safe
        // point. No platform task has run since the collection and no other
        // collection has begun.
        try page.run("d.nodeType;");
        // The released references made the dropped elements garbage: queued.
        try testing.expect(queue.queued_total > queued);
        proved = true;
    }
    try testing.expect(proved);
    queue.drainAll();
}

test "the binding's unwrap answers only for platform objects: no stray field, no CppHeap pointer it does not own" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var page = try Page.open(&queue);
    defer page.close();
    try page.openSecondRealm();
    try page.run("globalThis.d = new Document(); globalThis.div = d.createElement('div'); globalThis.h = new Headers();");
    try Page.runIn(page.other.?, "globalThis.theirs = new Document().createElement('section'); theirs.expando = 9;");
    // No platform object: a plain object, one with a node prototype, the
    // interface prototype objects themselves, a function.
    const none = [_][]const u8{ "({})", "Object.create(Node.prototype)", "Node.prototype", "HTMLDivElement.prototype", "Object.create(div)", "(function () {})" };
    for (none) |source| {
        if (try Page.instanceIn(page.realm, source)) |found| {
            std.debug.print("{s} unwrapped as a {s}\n", .{ source, found.vtable.name });
            return error.UnwrappedANonWrapper;
        }
    }
    // A non-node wrapper (internal fields) and a node wrapper (its anchor).
    try testing.expectEqualStrings("Headers", (try page.instance("h")).vtable.name);
    const div = try page.instance("div");
    try testing.expect(dom.instance_bridge.getNodeBase(div) != null);
    // A node of the agent's other realm: its one wrapper, unwrapped there
    // and here alike.
    const theirs = (try Page.instanceIn(page.other.?, "theirs")) orelse return error.NotAPlatformObject;
    try testing.expect(dom.instance_bridge.getNodeBase(theirs) != null);
    try testing.expect(div != theirs);
    // The binding: receivers and arguments that are no node throw.
    try testing.expect(try page.holds(
        \\(() => {
        \\  const bad = [{}, Object.create(Node.prototype), Node.prototype, h, Object.create(div)];
        \\  for (const b of bad) {
        \\    try { Node.prototype.appendChild.call(b, d.createElement('i')); return false; } catch (e) { if (!(e instanceof TypeError)) return false; }
        \\    try { div.appendChild(b); return false; } catch (e) { if (!(e instanceof TypeError)) return false; }
        \\    try { Object.getOwnPropertyDescriptor(Node.prototype, 'nodeName').get.call(b); return false; } catch (e) { if (!(e instanceof TypeError)) return false; }
        \\  }
        \\  return true;
        \\})()
    ));
    // structuredClone: a node is a platform object, never an ordinary one
    // (the serializer's IsHostObject; HTML StructuredSerializeInternal
    // step 26.3: DataCloneError).
    try testing.expect(try page.holds("(() => { div.expando = 1; try { structuredClone(div); return false; } catch (e) { return e.name === 'DataCloneError'; } })()"));
}
