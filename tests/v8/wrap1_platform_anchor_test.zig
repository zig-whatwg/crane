//! A non-node platform object's wrapper reaches its instance through `v8::Object::Wrap` (lane wrap1 b2, "the
//! link"; tmp/plans/object-wrap-design.md 3.4 and 5, the memory program's row R1).
//!
//! Until this batch every non-node wrapper kept its instance in an internal field. On V8 15.7 an aligned pointer
//! in an internal field is a cppgc object of V8's own (EmbedderDataSlotWrapper, 24 B with its header: 15.7.112.43
//! src/objects/embedder-data-slot-inl.h:209-227) plus a CppHeapPointerTable entry, and the field itself is 8 B of
//! the wrapper. Blink's wrappers have no internal field: the bindings generator reserves none, and
//! V8DOMWrapper::SetNativeInfo is `v8::Object::Wrap(isolate, wrapper, wrappable, this_tag)`
//! (third_party/blink/renderer/platform/bindings/v8_dom_wrapper.h:103-110, Chromium 157.0.8103.51); a node's
//! wrapper in Crane has had that shape since the wrapper redesign's P4 (tests/v8/node_anchor_test.zig). Here the
//! same holds for every other platform object: its interface's template has no internal field, the wrapper
//! points at a PlatformAnchor on the agent's C++ heap, and a holder of nodes (a NodeList, an HTMLCollection)
//! has ONE anchor, which also traces what it holds - not V8's slot wrapper and a HolderAnchor beside it.
//!
//! What script observes does not change, and is pinned here too: the brand check stays the instance's state
//! ancestry (tests/v8/v8up_a0_wrapper_field_test.zig), a legacy platform object's proxy still unwraps to its
//! target's instance, and a wrapper whose realm ended answers a TypeError, never a freed instance (Blink:
//! V8DOMWrapper::ClearNativeInfo).
//!
//! The last test is batch b3's first RED, pinned at today's value: what a dead wrapper leaves on the C++ heap
//! until the next full collection - the cause of the perf suite's dom.event-ctor rows.
//!
//! The collections are V8's own. The file shares tests/v8's process: it starts the engine as any file may and
//! makes its own agent per test.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        return .{ .agent = agent, .realm = try windowRealm(agent) };
    }

    fn windowRealm(agent: *protocol.Agent) !runtime.Context {
        return protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://wrap1.test",
            .global_this = .new_window_proxy,
            .create_global_object = WindowHost.createGlobalObject,
        });
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        // The adapter's Agent is the isolate (protocol.zig isolateOf).
        return @ptrCast(@alignCast(self.agent));
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    fn evalOwned(self: Page, source: []const u8) !protocol.Owned {
        return evalIn(self.realm, source);
    }

    fn run(self: Page, source: []const u8) !void {
        (try self.evalOwned(source)).release();
    }

    /// `source` answers "ok", or the failed cases.
    fn expectOk(self: Page, source: []const u8) !void {
        return expectOkIn(self.realm, source);
    }

    /// Two requested full collections (the second takes what the first's finalizers let go).
    fn fullGC(self: Page) void {
        const entered = self.enter();
        defer self.leave(entered);
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
    }

    /// V8's used heap bytes after full collections.
    fn heapUsed(self: Page) usize {
        self.fullGC();
        const entered = self.enter();
        defer self.leave(entered);
        var used: usize = 0;
        ffi.v8_Isolate_GetHeapUsage(self.isolate(), &used, null, null);
        return used;
    }

    /// The bytes of the objects on the agent's C++ heap after full collections (exact there: lesson
    /// testing-cppgc-used-bytes-cannot-show-an-explicit-free-between-collections.md).
    fn cppHeapUsed(self: Page) usize {
        self.fullGC();
        const entered = self.enter();
        defer self.leave(entered);
        return ffi.v8_Isolate_CppHeapUsedBytes(self.isolate());
    }

    /// The bytes alive on the agent's C++ heap, object by object - with no collection.
    fn cppLiveBytes(self: Page) usize {
        const entered = self.enter();
        defer self.leave(entered);
        return ffi.v8_test_CppHeap_LiveBytes(self.isolate());
    }

    /// At least `n` young-generation collections, then the agent's pump: its posted tasks and its safe
    /// point, where a collected wrapper's finalizer runs.
    fn minorGC(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
    }

    fn fullCollections(self: Page) u64 {
        var count: u64 = 0;
        var max_us: u64 = 0;
        var p95_us: u64 = 0;
        ffi.v8_Debug_FullGCPauses(self.isolate(), &count, &max_us, &p95_us);
        return count;
    }

    /// The adapter's counter `name`, with the page's isolate entered.
    fn counter(self: Page, name: []const u8) !i64 {
        const entered = self.enter();
        defer self.leave(entered);
        const counters = try protocol.diagnosticCounters(testing.allocator);
        defer testing.allocator.free(counters);
        for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
        std.debug.print("the adapter reports no counter named {s}\n", .{name});
        return error.CounterMissing;
    }
};

fn evalIn(realm: runtime.Context, source: []const u8) !protocol.Owned {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

/// `source` answers "ok", or its failed cases. Run as a block, so that one realm takes `checks` more than once.
fn expectOkIn(realm: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    const block = try std.fmt.allocPrint(testing.allocator, "{{\n{s}\n}}", .{source});
    defer testing.allocator.free(block);
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = block }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
    try testing.expectEqualStrings("ok", got);
}

/// The objects the tests read, on `globalThis.o`: a node, and non-node platform objects of every wrapper shape -
/// wrapped by Crane or bound to a constructor's `this`, a holder of nodes or not, behind a legacy platform
/// object's proxy or not.
const objects =
    \\const doc = new Document().implementation.createHTMLDocument("");
    \\const div = doc.createElement("div");
    \\div.setAttribute("data-k", "v");
    \\div.className = "a b";
    \\div.appendChild(doc.createElement("p"));
    \\doc.body.appendChild(div);
    \\globalThis.o = {
    \\  doc, div,                                  // nodes: their wrappers have had no field since P4
    \\  made: doc.createEvent("Event"),            // wrapped by Crane
    \\  url: new URL("https://wrap1.test/?a=1"),   // a constructor's `this`
    \\  event: new Event("x"),                     // a constructor's `this`
    \\  disguised: Reflect.construct(URL, ["https://wrap1.test/"], Event),  // NewTarget's prototype
    \\  tokens: div.classList,                     // DOMTokenList: indexed properties, no proxy
    \\  list: doc.querySelectorAll("p"),           // a static NodeList: a holder of nodes, no proxy
    \\  children: div.children,                    // HTMLCollection: a holder behind a proxy
    \\  attrs: div.attributes,                     // NamedNodeMap: behind a proxy
    \\  dataset: div.dataset,                      // DOMStringMap: behind a proxy
    \\};
    \\o.params = o.url.searchParams;               // wrapped by Crane ([SameObject])
    \\"made"
;

const checks =
    \\const failures = [];
    \\const check = (name, got, want) => { if (got !== want) failures.push(name + ": " + String(got)); };
    \\const throwsTypeError = (name, f) => {
    \\  try { f(); failures.push(name + ": did not throw"); }
    \\  catch (e) { if (!(e instanceof TypeError)) failures.push(name + ": threw " + e); }
    \\};
    \\const get = (I, n) => Object.getOwnPropertyDescriptor(I.prototype, n).get;
;

const non_node_names = [_][]const u8{ "made", "url", "event", "disguised", "tokens", "list", "children", "attrs", "dataset", "params" };

test "a non-node platform object's wrapper has no internal field, and the binding's read still finds its instance" {
    const page = try Page.open();
    defer page.close();
    try page.run(objects);

    var wrong: usize = 0;
    for ([_][]const u8{ "doc", "div" } ++ non_node_names) |name| {
        var source: [64]u8 = undefined;
        const got = try page.evalOwned(try std.fmt.bufPrint(&source, "o.{s}", .{name}));
        defer got.release();
        const object: *ffi.Object = @ptrCast(@alignCast(got.value.handle.ptr));
        // The count is read through a legacy platform object's proxy, of its target: the API object. The
        // instance is the binding's own read of a platform object (engine.convertToPlatformObject).
        const count = ffi.v8_Object_InternalFieldCount(object);
        const instance = protocol.convertToPlatformObject(page.realm, got.value);
        if (count != 0 or instance == null) {
            std.debug.print("o.{s}: {d} internal fields (expected 0), instance {s}\n", .{ name, count, if (instance == null) "not found" else "found" });
            wrong += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

test "members still reach their receivers' and arguments' instances, a proxy's target included" {
    const page = try Page.open();
    defer page.close();
    try page.run(objects);
    try page.expectOk(checks ++
        \\check("Event type", o.event.type, "x");
        \\check("createEvent's Event type", o.made.type, "");
        \\check("URL href", o.url.href, "https://wrap1.test/?a=1");
        \\check("URLSearchParams get", o.params.get("a"), "1");
        \\check("a disguised URL's href", get(URL, "href").call(o.disguised), "https://wrap1.test/");
        \\throwsTypeError("Event type on a URL with Event.prototype", () => o.disguised.type);
        \\check("DOMTokenList length", o.tokens.length, 2);
        \\check("DOMTokenList[1]", o.tokens[1], "b");
        \\check("NodeList length", o.list.length, 1);
        \\check("NodeList[0]", o.list[0], o.div.firstChild);
        \\check("HTMLCollection length, through its proxy", o.children.length, 1);
        \\check("HTMLCollection[0]", o.children[0], o.div.firstChild);
        \\check("HTMLCollection item()", o.children.item(0), o.div.firstChild);
        \\check("NamedNodeMap length", o.attrs.length, 2);
        \\check("NamedNodeMap named getter", o.attrs["data-k"].value, "v");
        \\check("DOMStringMap named getter", o.dataset.k, "v");
        \\o.dataset.n = "1";
        \\check("DOMStringMap named setter", o.div.getAttribute("data-n"), "1");
        \\// A platform object as an argument: the binding reads its instance the same way.
        \\check("dispatchEvent(a constructed Event)", o.div.dispatchEvent(o.event), true);
        \\check("dispatchEvent(createEvent's Event) is an InvalidStateError: not initialized",
        \\      (() => { try { o.div.dispatchEvent(o.made); } catch (e) { return e.name; } })(), "InvalidStateError");
        \\throwsTypeError("dispatchEvent(a URL)", () => o.div.dispatchEvent(o.url));
        \\throwsTypeError("appendChild(a NodeList)", () => o.div.appendChild(o.list));
        \\// A receiver of another interface, across the two wrapper kinds (node anchor, platform anchor).
        \\throwsTypeError("Node nodeName on an Event", () => get(Node, "nodeName").call(o.event));
        \\throwsTypeError("Event type on a div", () => get(Event, "type").call(o.div));
        \\throwsTypeError("HTMLCollection length on a NodeList", () => get(HTMLCollection, "length").call(o.list));
        \\throwsTypeError("NodeList length on an HTMLCollection's proxy", () => get(NodeList, "length").call(o.children));
        \\throwsTypeError("URL href on a plain object", () => get(URL, "href").call({}));
        \\throwsTypeError("URL href on Object.create(URL.prototype)", () => get(URL, "href").call(Object.create(URL.prototype)));
        \\throwsTypeError("URL href on URL.prototype", () => URL.prototype.href);
        \\// structuredClone refuses a platform object that is not serializable (HTML StructuredSerializeInternal
        \\// step 21: a DataCloneError), whatever its wrapper's shape.
        \\for (const name of ["event", "url", "params", "tokens", "list", "children", "attrs", "dataset", "div"]) {
        \\  let thrown = "nothing";
        \\  try { structuredClone(o[name]); } catch (e) { thrown = e.name; }
        \\  check("structuredClone(o." + name + ")", thrown, "DataCloneError");
        \\}
        \\failures.join("; ") || "ok"
    );
}

test "a kept wrapper costs one cppgc object: a plain platform object's anchor, and a holder's one anchor too" {
    // Per kept wrapper on the agent's C++ heap, before this batch: V8's slot wrapper for the field (24 B), and
    // for a holder of nodes wr1's HolderAnchor beside it (32 B): 56 B. With the link the anchor is the one
    // object: 24 B {vptr, instance}, 32 B for a holder {vptr, instance, generation}.
    const page = try Page.open();
    defer page.close();
    try page.run(objects);
    const n = 4000;

    const kinds = [_]struct { name: []const u8, make: []const u8, most: f64 }{
        .{ .name = "createEvent's Event (a plain platform object)", .make = "o.keep.push(doc2.createEvent('Event'))", .most = 26.0 },
        .{ .name = "a constructed URLSearchParams (a plain platform object)", .make = "o.keep.push(new URLSearchParams('a=b'))", .most = 26.0 },
        .{ .name = "querySelectorAll's NodeList (a holder of nodes)", .make = "o.keep.push(doc2.querySelectorAll('p'))", .most = 34.0 },
    };
    var wrong: usize = 0;
    for (kinds) |kind| {
        try page.run("o.keep = []; globalThis.doc2 = new Document().implementation.createHTMLDocument(''); 0");
        const before = page.cppHeapUsed();
        var source: [200]u8 = undefined;
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {s}; o.keep.length", .{ n, kind.make }));
        const after = page.cppHeapUsed();
        const per = @as(f64, @floatFromInt(after -| before)) / @as(f64, n);
        std.debug.print("{s}: {d:.1} B of CppHeap per kept wrapper ({d} -> {d})\n", .{ kind.name, per, before, after });
        if (per > kind.most or per < 16.0) wrong += 1;
        try page.run("o.keep = null; 0");
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

test "a kept non-node wrapper is a 16-byte object on V8's heap" {
    // 12 B of header and the 4 B CppHeap pointer handle (Blink's wrapper: design 1.1); the internal field was 8
    // more, 24 B. Kept in an array made at its full length before the first reading, so the difference between
    // the readings is the wrappers alone.
    const page = try Page.open();
    defer page.close();
    const n = 20000;
    var source: [200]u8 = undefined;
    try page.run(try std.fmt.bufPrint(&source, "globalThis.keep = new Array({d}); for (let i = 0; i < 64; i++) void new Event('x'); 0", .{n}));
    const before = page.heapUsed();
    try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) keep[i] = new Event('x'); keep.length", .{n}));
    const after = page.heapUsed();
    const per = @as(f64, @floatFromInt(after -| before)) / @as(f64, n);
    std.debug.print("a kept Event: {d:.1} B of V8 heap per wrapper ({d} -> {d})\n", .{ per, before, after });
    try testing.expect(per < 20.0);
    try testing.expect(per > 12.0);
    try page.run("globalThis.keep = null; 0");
}

test "a wrapper whose realm ended answers a TypeError, through a proxy too" {
    // Script elsewhere can outlive a realm and keep its objects' wrappers; the realm's end frees their
    // instances, so each wrapper is severed first (wrapper_cache.zig severWrapper; Blink clears a wrapper's
    // native info when its object goes, V8DOMWrapper::ClearNativeInfo): the next member call through it is
    // WebIDL's "not a platform object that implements the interface" TypeError, never a read of the freed
    // instance.
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const here = try Page.windowRealm(agent);
    defer protocol.destroyWindowRealm(here, .global_detached);
    const there = try Page.windowRealm(agent);
    var there_ended = false;
    defer if (!there_ended) protocol.destroyWindowRealm(there, .global_detached);
    {
        const theirs = try evalIn(there, objects ++
            \\; ({ event: o.event, made: o.made, params: o.params, tokens: o.tokens, list: o.list, children: o.children, attrs: o.attrs, dataset: o.dataset })
        );
        defer theirs.release();
        const global = try evalIn(here, "globalThis");
        defer global.release();
        try protocol.setProperty(here, global.value, "theirs", theirs.value);
    }
    // While their realm lives, this realm's members take them.
    try expectOkIn(here, checks ++
        \\check("their Event's type", get(Event, "type").call(theirs.event), "x");
        \\check("their URLSearchParams' get", URLSearchParams.prototype.get.call(theirs.params, "a"), "1");
        \\check("their NodeList's length", get(NodeList, "length").call(theirs.list), 1);
        \\check("their HTMLCollection's length", get(HTMLCollection, "length").call(theirs.children), 1);
        \\check("their NamedNodeMap's length", get(NamedNodeMap, "length").call(theirs.attrs), 2);
        \\failures.join("; ") || "ok"
    );

    protocol.destroyWindowRealm(there, .global_detached);
    there_ended = true;

    try expectOkIn(here, checks ++
        \\throwsTypeError("their Event's type", () => get(Event, "type").call(theirs.event));
        \\throwsTypeError("their createEvent Event's type", () => get(Event, "type").call(theirs.made));
        \\throwsTypeError("their URLSearchParams' get", () => URLSearchParams.prototype.get.call(theirs.params, "a"));
        \\throwsTypeError("their DOMTokenList's length", () => get(DOMTokenList, "length").call(theirs.tokens));
        \\throwsTypeError("their NodeList's length", () => get(NodeList, "length").call(theirs.list));
        \\throwsTypeError("their HTMLCollection's length", () => get(HTMLCollection, "length").call(theirs.children));
        \\throwsTypeError("their NamedNodeMap's length", () => get(NamedNodeMap, "length").call(theirs.attrs));
        \\throwsTypeError("their DOMStringMap as an Event", () => get(Event, "type").call(theirs.dataset));
        \\throwsTypeError("dispatchEvent(their Event)", () => new EventTarget().dispatchEvent(theirs.event));
        \\failures.join("; ") || "ok"
    );
    // And a full collection with the severed wrappers alive, then dropped, traces and frees nothing of theirs.
    {
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        ffi.v8_Isolate_RequestGarbageCollection(isolate);
    }
    try expectOkIn(here, "delete globalThis.theirs ? 'ok' : 'not deleted'");
    {
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        ffi.v8_Isolate_RequestGarbageCollection(isolate);
        ffi.v8_Isolate_RequestGarbageCollection(isolate);
    }
}

test "the snapshot generator refuses an API object that points at a C++-heap object" {
    // No platform object's wrapper is in the snapshot (the generator wraps none: the blob holds templates and
    // intrinsics). Before the link one that got there kept a null internal field; an anchor cannot be written
    // at all, and V8 calls the embedder's API wrapper serializer for it - a null callback when none is
    // registered (15.7.112.43 src/snapshot/context-serializer.cc:237-252). Blink's serializer aborts on any
    // wrappable but the one kind it expects (bindings/core/v8/v8_context_snapshot_impl.cc). Crane's refuses
    // every one: a guard, not a path. An API object nothing was wrapped with has nothing to write.
    try testing.expect(!ffi.v8_test_SnapshotRefusesApiWrapper(null));
    var anchor_stand_in: u64 = 0;
    try testing.expect(ffi.v8_test_SnapshotRefusesApiWrapper(&anchor_stand_in));
}

/// Batch b3 changes this to true, and the test below then holds the fixed value.
const dead_wrappers_freed_ahead_of_the_collector = false;

test "b3's first RED, pinned at today's value: a dead non-node wrapper leaves a cppgc object until the next full collection" {
    // The perf suite's dom.event-ctor and dom.event-ctor-dict each make and drop 650,000 Events
    // (tests/perf/workloads/attributes.html). A scavenge takes each dead wrapper and its finalizer frees the
    // Event, but the wrapper's cppgc object - V8's slot wrapper before the link, the PlatformAnchor after it,
    // 24 B either way - and its 8 B CppHeapPointerTable entry wait for a FULL collection, which V8 does not
    // schedule for them: 20.8 MB at the row's mark when none lands in the page (lane wrap1 b2 step 0, gc_bench:
    // 8.77 MB of C++ heap after 650,000 dropped Events and one full collection). b3 frees the anchor at the
    // agent's safe point after the scavenge and tells V8 of the table entry, as wr1 does for a node's
    // (v8_wrapper.cpp freeDroppedAnchors, reportDroppedTableEntries).
    const page = try Page.open();
    defer page.close();
    const n = 5000;
    try page.run("for (let i = 0; i < 64; i++) void new Event('x'); 0");

    var attempt: usize = 0;
    while (attempt < 4) : (attempt += 1) {
        page.fullGC();
        const entries_before = try page.counter("wrapper_cache_entries");
        const live_before = page.cppLiveBytes();
        const full_before = page.fullCollections();

        var source: [120]u8 = undefined;
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) void new Event('x'); 0", .{n}));
        try page.minorGC(4);

        // A full collection V8 chose to run meanwhile took what this reads: read again.
        if (page.fullCollections() != full_before) continue;
        // The scavenges took the wrappers and their finalizers ran: nothing of the Events is left but what
        // V8 keeps for them.
        try testing.expect(try page.counter("wrapper_cache_entries") <= entries_before + 8);
        const live_after = page.cppLiveBytes();
        const per = @as(f64, @floatFromInt(live_after -| live_before)) / @as(f64, n);
        std.debug.print("a dead Event wrapper leaves {d:.1} B of CppHeap until the next full collection ({d} -> {d})\n", .{ per, live_before, live_after });
        if (dead_wrappers_freed_ahead_of_the_collector) {
            try testing.expect(per < 2.0);
        } else {
            try testing.expect(per > 20.0 and per < 28.0);
        }

        // The full collection takes them.
        page.fullGC();
        const live_end = page.cppLiveBytes();
        const left = @as(f64, @floatFromInt(live_end -| live_before)) / @as(f64, n);
        try testing.expect(left < 2.0);
        return;
    }
    std.debug.print("a full collection ran in each of {d} attempts: nothing was read\n", .{attempt});
    return error.TestInconclusive;
}
