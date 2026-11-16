//! A non-node platform object's wrapper reaches its instance through `v8::Object::Wrap` (lane wrap1, "the link";
//! tmp/plans/object-wrap-design.md 3.4 and 5, the memory program's row R1).
//!
//! Until lane wrap1's batch 3 every non-node wrapper kept its instance in an internal field. On V8 15.7 an
//! aligned pointer in an internal field is a cppgc object of V8's own (EmbedderDataSlotWrapper, 24 B with its
//! header: 15.7.112.43 src/objects/embedder-data-slot-inl.h:209-227) plus a CppHeapPointerTable entry, and the
//! field itself is 8 B of the wrapper. Blink's wrappers have no internal field: the bindings generator reserves
//! none, and V8DOMWrapper::SetNativeInfo is `v8::Object::Wrap(isolate, wrapper, wrappable, this_tag)`
//! (third_party/blink/renderer/platform/bindings/v8_dom_wrapper.h:103-110, Chromium 157.0.8103.51); a node's
//! wrapper in Crane has had that shape since the wrapper redesign's P4 (tests/v8/node_anchor_test.zig). Now the
//! same holds for every other platform object: its interface's template has no internal field, the wrapper
//! points at a PlatformAnchor on the agent's C++ heap, and a holder of nodes (a NodeList, an HTMLCollection) has
//! ONE anchor, which also traces what it holds - not V8's slot wrapper and a HolderAnchor beside it.
//!
//! WHY IT WAITED ONE BATCH (the integrator's ruling, 2026-11-13). The link was written and measured in batch 2
//! (lane/wrap1 cd17108630e, reverted there): a kept wrapper is 8 B smaller on V8's heap, a kept holder 24 B
//! smaller on the C++ heap as well. But the wrapper is then 16 B in V8's young space instead of 24, so the
//! scavenger runs less often in a loop that makes and drops such objects (650,000 Events: 15 scavenges before,
//! 12 or 13 after), and each dead wrapper keeps its instance - 1.7 KB for an Event, which V8 was told nothing
//! about - until a scavenge finds it. The loop ended with 12% to 21% more resident memory
//! (tmp/plans/wrap1-evidence/meas1-c.out, meas1-l.out; lesson
//! architecture-a-smaller-wrapper-is-a-slower-scavenge.md). So it landed in batch 3 TOGETHER with the anchor
//! that replaces the weak-handle machinery (tests/v8/wrap1_anchor_lifetime_test.zig) and with the accounting
//! that tells V8 what a wrapper's instance holds. `non_node_wrappers_use_object_wrap` is the switch the two
//! batches turned; each test that reads it holds the link's value.
//!
//! What script observes did not change with the link, and is pinned here as plain tests: the brand check stays
//! the instance's state ancestry (tests/v8/v8up_a0_wrapper_field_test.zig), a legacy platform object's proxy
//! unwraps to its target's instance, and a wrapper whose realm ended answers a TypeError, never a freed instance
//! (Blink: V8DOMWrapper::ClearNativeInfo).
//!
//! The last test is what a dead wrapper leaves on the C++ heap until the next full collection - the cause of
//! the perf suite's dom.event-ctor rows.
//!
//! The collections are V8's own. The file shares tests/v8's process: it starts the engine as any file may and
//! makes its own agent per test.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
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

/// True since lane wrap1's batch 3 (the file's header says why the link waited for it): each test that reads it
/// holds the link's value.
const non_node_wrappers_use_object_wrap = true;

test "a non-node platform object's wrapper has no internal field, and the binding's read finds its instance" {
    const page = try Page.open();
    defer page.close();
    try page.run(objects);

    var wrong: usize = 0;
    for ([_][]const u8{ "doc", "div" } ++ non_node_names, 0..) |name, index| {
        // A node's wrapper has had no field since the wrapper redesign's P4; every other wrapper since the link.
        const is_node = index < 2;
        const expected: c_int = if (is_node or non_node_wrappers_use_object_wrap) 0 else 1;
        var source: [64]u8 = undefined;
        const got = try page.evalOwned(try std.fmt.bufPrint(&source, "o.{s}", .{name}));
        defer got.release();
        const object: *ffi.Object = @ptrCast(@alignCast(got.value.handle.ptr));
        // The count is read through a legacy platform object's proxy, of its target: the API object. The
        // instance is the binding's own read of a platform object (engine.convertToPlatformObject).
        const count = ffi.v8_Object_InternalFieldCount(object);
        const instance = protocol.convertToPlatformObject(page.realm, got.value);
        if (count != expected or instance == null) {
            std.debug.print("o.{s}: {d} internal fields (expected {d}), instance {s}\n", .{ name, count, expected, if (instance == null) "not found" else "found" });
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

test "a kept holder of nodes costs one cppgc object, as a plain platform object does" {
    // Per kept wrapper on the agent's C++ heap today: V8's slot wrapper for the field (24 B), and for a holder
    // of nodes wr1's HolderAnchor beside it (32 B): 56 B. With the link the anchor is the one object: 24 B
    // {vptr, instance}, 32 B for a holder {vptr, instance, generation}.
    const page = try Page.open();
    defer page.close();
    try page.run(objects);
    const n = 4000;

    const holder_least: f64 = if (non_node_wrappers_use_object_wrap) 16.0 else 50.0;
    const holder_most: f64 = if (non_node_wrappers_use_object_wrap) 34.0 else 58.0;
    const kinds = [_]struct { name: []const u8, make: []const u8, least: f64, most: f64 }{
        .{ .name = "createEvent's Event (a plain platform object)", .make = "o.keep.push(doc2.createEvent('Event'))", .least = 16.0, .most = 26.0 },
        .{ .name = "a constructed URLSearchParams (a plain platform object)", .make = "o.keep.push(new URLSearchParams('a=b'))", .least = 16.0, .most = 26.0 },
        .{ .name = "querySelectorAll's NodeList (a holder of nodes)", .make = "o.keep.push(doc2.querySelectorAll('p'))", .least = holder_least, .most = holder_most },
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
        if (per > kind.most or per < kind.least) wrong += 1;
        try page.run("o.keep = null; 0");
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

test "a kept non-node wrapper is a 16-byte object on V8's heap" {
    // 12 B of header and the 4 B CppHeap pointer handle (Blink's wrapper: design 1.1); the internal field is 8
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
    if (non_node_wrappers_use_object_wrap) {
        try testing.expect(per > 12.0 and per < 20.0);
    } else {
        try testing.expect(per > 20.0 and per < 28.0);
    }
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
    // intrinsics). Today one that got there keeps a null internal field. With the link it would point at an
    // anchor, which cannot be written at all, and V8 calls the embedder's API wrapper serializer for it - a
    // null callback when none is registered (15.7.112.43 src/snapshot/context-serializer.cc:237-252). Blink's
    // serializer aborts on any wrappable but the one kind it expects
    // (bindings/core/v8/v8_context_snapshot_impl.cc). The link's refuses every one: a guard, not a path. An API
    // object nothing was wrapped with has nothing to write, with the guard or without.
    try testing.expect(!ffi.v8_test_SnapshotRefusesApiWrapper(null));
    var anchor_stand_in: u64 = 0;
    try testing.expectEqual(non_node_wrappers_use_object_wrap, ffi.v8_test_SnapshotRefusesApiWrapper(&anchor_stand_in));
}

// ---- The anchor in place of the weak-handle machinery (lane wrap1 b3; tmp/plans/object-wrap-design.md 3.4) ----

/// One row of the kept-wrapper pins: `make` pushes one object of the shape onto `o.keep`.
const KeptShape = struct {
    name: []const u8,
    make: []const u8,
    /// The agent's C++ heap per kept object, bytes: the shape's anchors (24 B a non-node platform object's, 32 B
    /// a node's when the row makes one too).
    cpp_least: f64,
    cpp_most: f64,
    /// V8's handle tables per kept object, bytes: 16 for each traced reference - the cache's record's, and the
    /// node's slot when the row makes a node too - and 32 for the weak v8::Global of a record whose wrapper V8
    /// would not drop in a young collection (an Event, a legacy platform object's proxy, a wrapper the binding
    /// drew a [SameObject] edge on). Until lane wrap1 b3 every record's handle was a Global in a box.
    handles_most: f64,
};

/// Every wrapper shape the binding makes for a non-node platform object (lesson
/// testing-measure-a-kept-object-of-every-wrapper-shape-not-one-representative.md): a constructor's receiver, an
/// object Crane wrapped, one with indexed properties, a holder of nodes, and one behind a legacy platform
/// object's proxy. The DOMTokenList and the HTMLCollection each come with the div they hang from (its node
/// anchor: 32 B).
const kept_shapes = [_]KeptShape{
    .{ .name = "Event (a constructor's receiver; born with an own property: a weak handle)", .make = "o.keep.push(new Event('x'))", .cpp_least = 16.0, .cpp_most = 26.0, .handles_most = 32.5 },
    .{ .name = "URLSearchParams (a constructor's receiver)", .make = "o.keep.push(new URLSearchParams('a=b'))", .cpp_least = 16.0, .cpp_most = 26.0, .handles_most = 16.5 },
    .{ .name = "Headers (a constructor's receiver)", .make = "o.keep.push(new Headers())", .cpp_least = 16.0, .cpp_most = 26.0, .handles_most = 16.5 },
    .{ .name = "createEvent's Event (wrapped by Crane; a weak handle)", .make = "o.keep.push(doc2.createEvent('Event'))", .cpp_least = 16.0, .cpp_most = 26.0, .handles_most = 32.5 },
    .{ .name = "a div's DOMTokenList (indexed properties; a [SameObject] edge: a weak handle; with its div)", .make = "o.keep.push(doc2.createElement('div').classList)", .cpp_least = 48.0, .cpp_most = 60.0, .handles_most = 48.5 },
    .{ .name = "querySelectorAll's NodeList (a holder of nodes)", .make = "o.keep.push(doc2.querySelectorAll('p'))", .cpp_least = 16.0, .cpp_most = 26.0, .handles_most = 16.5 },
    .{ .name = "a div's HTMLCollection (a holder behind a proxy: a weak handle; with its div)", .make = "o.keep.push(doc2.createElement('div').children)", .cpp_least = 48.0, .cpp_most = 60.0, .handles_most = 48.5 },
    // The two other holders lane wrap1's brief named (lane wrap2): each is ONE anchor and one record, as the two
    // above. A MutationRecord comes from an observer's queue (its record and the node it names are the page's
    // already); a computed style declaration holds its element.
    .{ .name = "a MutationRecord (a holder of nodes)", .make = "(doc2.body.firstChild.textContent = 'x' + i, o.keep.push(o.observer.takeRecords()[0]))", .cpp_least = 16.0, .cpp_most = 26.0, .handles_most = 16.5 },
    .{ .name = "getComputedStyle's CSSStyleDeclaration (a holder behind a proxy: a weak handle)", .make = "o.keep.push(getComputedStyle(doc2.body.firstChild))", .cpp_least = 16.0, .cpp_most = 26.0, .handles_most = 32.5 },
};

test "a kept non-node wrapper of every shape costs one handle in the cache's own record and one anchor on the C++ heap" {
    // Until lane wrap1's batch 3 the wrapper cache kept each non-node wrapper by a weak v8::Global with a
    // callback record: a 32 B global-handle node of V8's, a 16 B box, a 48 B record, a node in the adapter's
    // armed-handle map and an 88 B cache entry - about 200 of the 312-320 B a kept wrapper cost (gc_bench,
    // tmp/plans/wrap1-evidence/meas0-c.out). Now the wrapper's anchor is what the cache holds it by: the anchor
    // names a 32 B record of the cache's (instance, slab generation, the wrapper as a v8::TracedReference - 16 B
    // of V8's traced handles, which its handle bytes count where a weak Global's node was 32), the cache's map
    // names the record, and the collector finds a dead wrapper through its anchor. Blink holds a wrapper the
    // same way: a TraceWrapperV8Reference in the ScriptWrappable, no v8::Global
    // (platform/bindings/script_wrappable.h:147, dom_data_store.h). The record's own size is pinned where it is
    // declared (wrapper_cache.zig `Cell`: 32 bytes, checked at compile time). A wrapper V8 would not drop in a
    // young collection is held by a weak v8::Global made in that same record (the tests below): 32 B of V8's
    // handles, with no box and no 88-byte entry.
    const page = try Page.open();
    defer page.close();
    try page.run(objects);
    const n = 2000;

    var wrong: usize = 0;
    for (kept_shapes) |shape| {
        try page.run("o.keep = []; globalThis.doc2 = new Document().implementation.createHTMLDocument(''); doc2.body.appendChild(doc2.createElement('p')); if (o.observer) o.observer.disconnect(); o.observer = new MutationObserver(() => {}); o.observer.observe(doc2.body, { childList: true, subtree: true }); 0");
        var source: [320]u8 = undefined;
        // Once before the reading: whatever the shape makes once per realm (templates, prototypes).
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < 8; i++) {s}; o.keep.length", .{shape.make}));
        const cpp_before = page.cppHeapUsed();
        const handles_before = try page.counter("global_handle_bytes");
        const entries_before = try page.counter("wrapper_cache_entries");
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {s}; o.keep.length", .{ n, shape.make }));
        const cpp_after = page.cppHeapUsed();
        const handles_after = try page.counter("global_handle_bytes");
        const entries_after = try page.counter("wrapper_cache_entries");

        const cpp = @as(f64, @floatFromInt(cpp_after -| cpp_before)) / @as(f64, n);
        const handles = @as(f64, @floatFromInt(handles_after - handles_before)) / @as(f64, n);
        const entries = @as(f64, @floatFromInt(entries_after - entries_before)) / @as(f64, n);
        std.debug.print("{s}: {d:.1} B of V8 handles, {d:.1} B of CppHeap, {d:.2} cache entries per kept object\n", .{ shape.name, handles, cpp, entries });
        // The cache still knows each one (identity), by one entry.
        if (entries < 0.99 or entries > 1.01) wrong += 1;
        if (handles > shape.handles_most) wrong += 1;
        if (cpp < shape.cpp_least or cpp > shape.cpp_most) wrong += 1;
        try page.run("o.keep = null; 0");
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

test "a young collection takes every dead wrapper the cache knows of: unchanged, born with an own property, or changed by the binding; one script changed waits for a full collection" {
    // V8 drops a wrapper held by a DROPPABLE traced reference in a young-generation collection only while it is
    // an unmodified API object - its map still its constructor's initial map, no elements, no identity hash
    // (15.7.112.43 src/handles/traced-handles.cc:519-533, src/objects/js-objects.cc:3152-3168); any other is a
    // root there and waits for a FULL collection, which V8 runs about every 100 MB of memory it is told of. So
    // the cache holds by a traced reference only a wrapper V8 can drop, and every wrapper it knows V8 would not
    // drop by a weak v8::Global, which a young collection processes whatever the map (wrapper_cache.zig
    // `heldByWeakHandle`, the rule stated once):
    // - an Event: its [LegacyUnforgeable] isTrusted (DOM 2.2) is an own property V8 adds after it makes the
    //   object from the initial map (src/api/api-natives.cc:351-356);
    // - a URL once its searchParams was read: the binding drew the [SameObject] edge on the wrapper.
    // A wrapper SCRIPT changed (an expando) the cache does not know of: it waits for a full collection, as in
    // Blink, and as a node's wrapper does. (With traced references alone 650,000 dropped Events ended at
    // 198 MB against main's 88: tmp/plans/wrap1-evidence/b3-meas3-drop-l.out.)
    const page = try Page.open();
    defer page.close();
    const n = 1000;
    try page.run("for (let i = 0; i < 64; i++) { void new Event('x'); void new URLSearchParams('a=b'); void new URL('https://wrap1.test/?a=1').searchParams; } 0");

    var attempt: usize = 0;
    while (attempt < 4) : (attempt += 1) {
        page.fullGC();
        const entries_before = try page.counter("wrapper_cache_entries");
        const full_before = page.fullCollections();
        var source: [200]u8 = undefined;
        const kinds = [_][]const u8{
            "void new URLSearchParams('a=b')", // unchanged: a traced reference, dropped
            "void new Event('x')", // born with an own property: a weak handle
            "void new URL('https://wrap1.test/?a=1').searchParams", // the binding's edge, on both: weak handles
        };
        for (kinds) |kind| try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {s}; 0", .{ n, kind }));
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {{ const p = new URLSearchParams('a=b'); p.mine = i; }} 0", .{n}));
        try page.minorGC(4);
        // A full collection V8 chose to run meanwhile took every kind: read again.
        if (page.fullCollections() != full_before) continue;
        const entries_young = try page.counter("wrapper_cache_entries");
        std.debug.print("after young collections: {d} dead wrappers are still cached, of {d} each of: unchanged URLSearchParams, Events, URLs with their searchParams, URLSearchParams with an expando\n", .{ entries_young - entries_before, n });
        // Only the ones script changed wait.
        try testing.expect(entries_young >= entries_before + n - 8);
        try testing.expect(entries_young <= entries_before + n + 8);
        page.fullGC();
        try testing.expect(try page.counter("wrapper_cache_entries") <= entries_before + 8);
        return;
    }
    std.debug.print("a full collection ran in each of {d} attempts: nothing was read\n", .{attempt});
    return error.TestInconclusive;
}

test "the cache's pool of records gives its memory back once a burst of wrappers is collected" {
    // The cache issues its 32-byte records from chunks of its own (wrapper_cache.zig `Chunk`). A page that holds
    // many wrappers at once - 20,000 streams with their readers waiting for a collection - grows the pool; once
    // they are collected the pool must shrink again, as the cache's 88-byte entries did when each was its own
    // allocation: a chunk nothing uses pins its page of the process's heap for the realm's life. One chunk may
    // stay, so that a wrapper made and dropped at a chunk's edge does not allocate each time.
    const page = try Page.open();
    defer page.close();
    try page.run("for (let i = 0; i < 64; i++) void new URLSearchParams('a=b'); 0");
    page.fullGC();
    const before = try page.counter("wrapper_cache_pool_bytes");
    const n = 6000;
    var source: [160]u8 = undefined;
    try page.run(try std.fmt.bufPrint(&source, "globalThis.keep = []; for (let i = 0; i < {d}; i++) keep.push(new URLSearchParams('a=b')); 0", .{n}));
    const grown = try page.counter("wrapper_cache_pool_bytes");
    try page.run("globalThis.keep = null; 0");
    page.fullGC();
    page.fullGC();
    const after = try page.counter("wrapper_cache_pool_bytes");
    std.debug.print("the pool: {d} B before, {d} B with {d} kept wrappers, {d} B after their collection\n", .{ before, grown, n, after });
    try testing.expect(grown >= before + n * 32);
    // Back to where it was, within the one spare chunk and the chunks the realm's own few wrappers sit in.
    try testing.expect(after <= before + 4 * 1024);
}

test "the cache's map gives its slots back once a burst of wrappers is collected, and still answers for the rest" {
    // The cache's map is std's, which only grows: a slot (17 bytes) per live non-node wrapper at the page's
    // high-water mark, for the realm's life. The perf suite's streams page holds 200,000 streams with their
    // readers and controllers at once - a million slots, 17.8 MB that stayed after everything was collected
    // (lane wrap1 b3's reading of that page: "the cache's map 17.8 MB"). The map now follows the live
    // wrappers down, as the pool does (the test above): rebuilt smaller where a record is freed, once an
    // eighth or less of more than `map_shrink_floor` slots is in use.
    const WrapperCache = @import("v8").WrapperCache;
    const page = try Page.open();
    defer page.close();
    const cache: *WrapperCache = @ptrCast(@alignCast(page.realm.getV8WrapperCacheStorage() orelse return error.NoCache));
    const floor = WrapperCache.map_shrink_floor;
    // A burst well over the floor, beside five wrappers that stay.
    const n = 120_000;
    var source: [200]u8 = undefined;
    try page.run("globalThis.stay = []; for (let i = 0; i < 5; i++) { const p = new URLSearchParams('a=' + i); p.mine = i; stay.push(p); } 0");
    try page.run(try std.fmt.bufPrint(&source, "globalThis.keep = []; for (let i = 0; i < {d}; i++) keep.push(new URLSearchParams('a=b')); 0", .{n}));
    const peak = cache.cache.capacity();
    try testing.expect(cache.cache.count() >= n and peak > floor);
    try page.run("globalThis.keep = null; 0");
    page.fullGC();
    page.fullGC();
    const after = cache.cache.capacity();
    std.debug.print("the map: {d} slots with {d} kept wrappers, {d} slots after their collection ({d} entries)\n", .{ peak, n, after, cache.cache.count() });
    try testing.expect(cache.cache.count() < 64);
    // Std's map alone would still hold `peak` slots.
    try testing.expect(after <= floor and after * 4 <= peak);
    // The wrappers that stayed are the same objects, found by the same records.
    try page.expectOk("stay.every((p, i) => p.mine === i && p.get('a') === String(i)) ? 'ok' : 'a wrapper that stayed was lost'");
    try page.run("globalThis.stay = null; 0");
    page.fullGC();
}

test "a young collection takes the dead wrappers of objects script only made and dropped, shape by shape" {
    // The make-and-drop loops of the perf suite (tests/perf/workloads/streams.html, timers.html, events.html)
    // make objects script never changes and drop them. Whatever the binding itself does to their wrappers - a
    // traced child, a [SameObject] value, a private property the streams code keeps - the cache must hold each by
    // a handle a young collection processes (wrapper_cache.zig `heldByWeakHandle`), or they wait for a full
    // collection: promoted, with what their instances hold. Each shape alone, so a failure names it. (A pin: it
    // passed when it was written, lane wrap1 b3 - the streams rows' cost had another cause.)
    const page = try Page.open();
    defer page.close();
    const n = 500;
    const shapes = [_]struct { name: []const u8, make: []const u8 }{
        .{ .name = "a ReadableStream", .make = "void new ReadableStream({ start(c) { c.close(); } })" },
        .{ .name = "a ReadableStream with its reader", .make = "void new ReadableStream({ start(c) { c.close(); } }).getReader()" },
        .{ .name = "a TransformStream", .make = "void new TransformStream()" },
        .{ .name = "a WritableStream", .make = "void new WritableStream()" },
        .{ .name = "a MessageChannel", .make = "void new MessageChannel()" },
        .{ .name = "a CustomEvent", .make = "void new CustomEvent('x', { detail: 1 })" },
        .{ .name = "an AbortController", .make = "void new AbortController()" },
        .{ .name = "a Headers", .make = "void new Headers({ a: 'b' })" },
        .{ .name = "a Response", .make = "void new Response('x')" },
        .{ .name = "a TextDecoderStream", .make = "void new TextDecoderStream()" },
    };
    var waiting_shapes: usize = 0;
    for (shapes) |shape| {
        var source: [240]u8 = undefined;
        // Once before the reading: whatever the shape makes once per realm.
        page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < 8; i++) {s}; 0", .{shape.make})) catch {
            std.debug.print("{s}: not made in this realm, skipped\n", .{shape.name});
            continue;
        };
        var attempt: usize = 0;
        while (attempt < 4) : (attempt += 1) {
            page.fullGC();
            const entries_before = try page.counter("wrapper_cache_entries");
            const full_before = page.fullCollections();
            try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {s}; 0", .{ n, shape.make }));
            const entries_made = try page.counter("wrapper_cache_entries");
            try page.minorGC(4);
            if (page.fullCollections() != full_before) continue;
            const entries_young = try page.counter("wrapper_cache_entries");
            std.debug.print("{s}: {d} wrappers cached for {d} made; {d} still cached after young collections\n", .{ shape.name, entries_made - entries_before, n, entries_young - entries_before });
            if (entries_young > entries_before + 8) waiting_shapes += 1;
            break;
        }
        page.fullGC();
    }
    try testing.expectEqual(@as(usize, 0), waiting_shapes);
}

test "the cache's rule for a weak handle is V8's own answer, template by template: an instance V8 would not drop is born changed" {
    // The rule (wrapper_cache.zig `heldByWeakHandle`): a wrapper V8 would not treat as an unmodified API object
    // is held by a weak handle. For "from birth" the cache answers from the interface's metadata
    // (interface_bindings.wrapperIsBornChanged); here V8 is asked itself, with lane wr1's probe: an instance of
    // the interface's template, held by a droppable traced reference alone - does a young collection drop it?
    // Every interface the cache calls born changed must NOT be dropped, and a sample of the others must be. A
    // new interface with a [LegacyUnforgeable] member is covered by both sides with no list to edit; a V8 that
    // changes its rule fails here (and v8_wrapper.cpp's version assert asks for the re-read first).
    @setEvalBranchQuota(10_000_000);
    const v8 = @import("v8");
    const page = try Page.open();
    defer page.close();
    const entered = page.enter();
    defer page.leave(entered);
    const context: *ffi.Context = @ptrCast(@alignCast(page.realm.engine_ctx.?));

    var asked: usize = 0;
    var born_changed: usize = 0;
    var wrong: usize = 0;
    var inconclusive: usize = 0;
    var index: usize = 0;
    inline for (@typeInfo(interfaces).@"struct".decl_names) |decl_name| {
        const Interface = @field(interfaces, decl_name);
        if (comptime @typeInfo(Interface) == .@"struct" and @hasDecl(Interface, "Meta") and @hasDecl(Interface.Meta, "name")) {
            const name: []const u8 = Interface.Meta.name;
            index += 1;
            const changed = v8.interface_bindings.wrapperIsBornChanged(name);
            // A legacy platform object's wrapper is a Proxy around its template's instance - no API object at
            // all (js-objects-inl.h IsDroppableApiObject) - so the template's own instance says nothing of it.
            const proxied = v8.template_registry.isLegacyPlatformObject(name);
            // Every born-changed interface, and every sixteenth of the rest. A realm's global is no wrapper of
            // the cache's.
            const sampled = (changed and !proxied) or (!changed and index % 16 == 0);
            if (sampled and !std.mem.eql(u8, name, "Window")) {
                if (v8.template_registry.getTemplateForIsolate(name, page.isolate())) |template| {
                    const outcome = ffi.v8_test_NodeTemplateWrapperDroppable(page.isolate(), context, template, null, false, null);
                    if (outcome < 0) {
                        inconclusive += 1;
                    } else {
                        asked += 1;
                        if (changed) born_changed += 1;
                        if ((outcome == 0) != changed) {
                            std.debug.print("{s}: V8 says droppable = {d}, the cache says born changed = {}\n", .{ name, outcome, changed });
                            wrong += 1;
                        }
                    }
                }
            }
        }
    }
    std.debug.print("asked V8 about {d} templates ({d} born changed, {d} inconclusive)\n", .{ asked, born_changed, inconclusive });
    try testing.expectEqual(@as(usize, 0), wrong);
    // Both sides were asked: Event and its descendants alone are dozens.
    try testing.expect(born_changed >= 20 and asked - born_changed >= 20);
    try testing.expect(v8.interface_bindings.wrapperIsBornChanged("Event"));
    try testing.expect(v8.interface_bindings.wrapperIsBornChanged("CustomEvent"));
    try testing.expect(v8.interface_bindings.wrapperIsBornChanged("HTMLCollection"));
    try testing.expect(!v8.interface_bindings.wrapperIsBornChanged("URLSearchParams"));
    try testing.expect(!v8.interface_bindings.wrapperIsBornChanged("Headers"));
}

/// True since lane wrap1's batch 3: the test below holds the fixed value (until then a dead wrapper left its
/// 24 B cppgc object until the next full collection: 20 to 28 B per dead Event, measured by this test).
const dead_wrappers_freed_ahead_of_the_collector = true;

test "a dead non-node wrapper's anchor is freed at the agent's safe point after the young collection that took it, whichever handle held it" {
    // The perf suite's dom.event-ctor and dom.event-ctor-dict each make and drop 650,000 Events
    // (tests/perf/workloads/attributes.html). A scavenge takes each dead wrapper and its finalizer frees the
    // Event, but until lane wrap1's batch 3 the wrapper's cppgc object - V8's slot wrapper before the link, the
    // PlatformAnchor after it, 24 B either way - and its 8 B CppHeapPointerTable entry waited for a FULL
    // collection, which V8 does not schedule for them: 20.8 MB at the row's mark when none lands in the page
    // (lane wrap1 b2 step 0, gc_bench: 8.77 MB of C++ heap after 650,000 dropped Events and one full
    // collection). Now the anchor is freed at the agent's safe point after the scavenge and V8 is told of the
    // table entry, as wr1 does for a node's - for a wrapper held by a traced reference (a URLSearchParams:
    // v8_wrapper.cpp resetPlatformRoot) and for one held by a weak handle (an Event: dropDeadWrapperAnchor, from
    // its Global's first pass) alike (freeDroppedAnchors, reportDroppedTableEntries).
    const page = try Page.open();
    defer page.close();
    const n = 5000;
    try page.run("for (let i = 0; i < 64; i++) { void new URLSearchParams('a=b'); void new Event('x'); } 0");

    for ([_][]const u8{ "void new URLSearchParams('a=b')", "void new Event('x')" }) |make| {
        var done = false;
        var attempt: usize = 0;
        while (attempt < 4 and !done) : (attempt += 1) {
            page.fullGC();
            const entries_before = try page.counter("wrapper_cache_entries");
            const live_before = page.cppLiveBytes();
            const full_before = page.fullCollections();

            var source: [120]u8 = undefined;
            try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {s}; 0", .{ n, make }));
            try page.minorGC(4);

            // A full collection V8 chose to run meanwhile took what this reads: read again.
            if (page.fullCollections() != full_before) continue;
            // The scavenges took the wrappers and their finalizers ran: nothing of the objects is left but what
            // V8 keeps for them.
            try testing.expect(try page.counter("wrapper_cache_entries") <= entries_before + 8);
            const live_after = page.cppLiveBytes();
            const per = @as(f64, @floatFromInt(live_after -| live_before)) / @as(f64, n);
            std.debug.print("a dead wrapper ({s}) leaves {d:.1} B of CppHeap until the next full collection ({d} -> {d})\n", .{ make, per, live_before, live_after });
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
            done = true;
        }
        if (!done) {
            std.debug.print("a full collection ran in each of {d} attempts: nothing was read\n", .{attempt});
            return error.TestInconclusive;
        }
    }
}

test "a handle borrowed from the cache reads empty once a collection took its wrapper, until the finalizer frees its record" {
    // Every caller of the binding borrows the cache's handle to a wrapper by ADDRESS (WrapperCache.get,
    // conversions.instanceToV8). The handle is the cache's record of the wrapper, which is the cache's own
    // memory and not the wrapper's anchor: an anchor a full collection finds dead is swept at once and its
    // memory given to the next anchor, so a handle inside it could read another object's wrapper. The record
    // outlives the wrapper - emptied by the collection, out of the cache's map, freed by the wrapper's
    // finalizer at the agent's safe point - as the weak v8::Global's box did before lane wrap1's batch 3 (the
    // integrator's ruling, 2026-11-14: 8 B a wrapper is the price).
    const WrapperCache = @import("v8").WrapperCache;
    const page = try Page.open();
    defer page.close();
    const cache: *WrapperCache = @ptrCast(@alignCast(page.realm.getV8WrapperCacheStorage() orelse return error.NoCache));

    // The handle is the record's address for both of a record's kinds, so one borrowed before the binding
    // changed the wrapper (a traced reference becomes a weak Global, in place) is the same handle after.
    {
        const got = try page.evalOwned("globalThis.u = new URL('https://wrap1.test/?a=1'); u");
        defer got.release();
        const instance = protocol.convertToPlatformObject(page.realm, got.value) orelse return error.NoInstance;
        const handle = cache.get(instance) orelse return error.NotCached;
        try page.run("void u.searchParams; 0");
        try testing.expectEqual(handle, cache.get(instance) orelse return error.NotCached);
        try testing.expect(!ffi.v8_Global_IsEmpty(@ptrCast(handle)));
        // And it still names the URL's wrapper.
        try testing.expectEqual(instance, protocol.convertToPlatformObject(page.realm, got.value) orelse return error.NoInstance);
        try page.expectOk("u.href === 'https://wrap1.test/?a=1' && u.searchParams.get('a') === '1' ? 'ok' : 'the URL changed'");
        try page.run("globalThis.u = null; 0");
    }
    // The URL and its URLSearchParams are dead now: collected and finalized here, so that the collections
    // below take exactly the one wrapper each is about.
    page.fullGC();

    const Kind = enum { young, full };
    for ([_]Kind{ .young, .full }) |kind| {
        // An unchanged wrapper for the young collection (V8 drops it there); an Event script changed for the
        // full one (a root in young collections, so only the full collection takes it).
        const got = try page.evalOwned(switch (kind) {
            .young => "globalThis.h = new URLSearchParams('a=b'); h",
            .full => "globalThis.h = new Event('x'); h.mine = 1; h",
        });
        const instance = protocol.convertToPlatformObject(page.realm, got.value) orelse return error.NoInstance;
        const generation = runtime.SlabAllocator.generationOf(instance);
        const handle = cache.get(instance) orelse return error.NotCached;
        try testing.expect(!ffi.v8_Global_IsEmpty(@ptrCast(handle)));
        got.release();
        try page.run("globalThis.h = null; 0");
        const pending_before = cache.pendingFinalizerCount();

        {
            const entered = page.enter();
            defer page.leave(entered);
            switch (kind) {
                .young => ffi.v8_test_Isolate_MinorGC(page.isolate(), 4),
                .full => ffi.v8_test_Isolate_CollectWithoutDrain(page.isolate()),
            }
            // The collection took the wrapper and nothing ran after it: the record waits for its finalizer.
            // The borrowed handle is still the record's, and reads empty; the cache answers nothing for the
            // instance, which is not torn down yet.
            try testing.expect(ffi.v8_Global_IsEmpty(@ptrCast(handle)));
            try testing.expect(cache.get(instance) == null);
            try testing.expectEqual(pending_before + 1, cache.pendingFinalizerCount());
            try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(instance));
            // The agent's safe point: the finalizer tears the instance down and frees the record.
            while (ffi.v8_Platform_PumpMessageLoop(page.isolate())) {}
            _ = ffi.v8_Isolate_RunQueuedFinalizers(page.isolate());
        }
        try testing.expectEqual(pending_before, cache.pendingFinalizerCount());
        try testing.expect(generation != runtime.SlabAllocator.generationOf(instance));
    }
}

/// True since lane wrap1's batch 3 (the escalated agent's review of the weak-handle records): the test below holds
/// the fixed value. Before, the anchor of a wrapper held by a weak handle still named the cache's record after a
/// collection that took the wrapper and kept the anchor.
const an_anchor_that_outlives_its_wrapper_names_no_record = true;

/// A full collection with the stack scanned, from a frame of its own that keeps `word` in memory: the caller's
/// local holds an anchor's address, and the scan must find it there.
noinline fn collectScanningStack(isolate: *ffi.Isolate, word: *volatile usize) void {
    ffi.v8_test_Isolate_CollectScanningStack(isolate);
    std.mem.doNotOptimizeAway(word.*);
}

test "an anchor a scan of the stack keeps past its wrapper's death names no record of the cache" {
    // V8 scans the native stack conservatively when a collection runs under script: a word that happens to hold a
    // C++-heap object's address keeps that object for the collection, and its Trace runs. For a wrapper the cache
    // holds by a TRACED reference that is consistent: the anchor's Trace keeps the wrapper, so anchor, wrapper and
    // record live or die together. A wrapper held by a WEAK HANDLE (an Event: born with an own property) is not
    // kept by its anchor - nothing traces a weak v8::Global - so the wrapper dies, its record's finalizer frees
    // the record at the agent's safe point, and the anchor lives on. If it still named the record, its Trace in
    // the next collection would read memory the cache has freed (the record's chunk goes back to the allocator
    // with its last record) or issued to another wrapper. Blink has no such pair: a wrapper's ScriptWrappable is
    // the object itself and holds nothing that is freed apart from it.
    const WrapperCache = @import("v8").WrapperCache;
    const page = try Page.open();
    defer page.close();
    const cache: *WrapperCache = @ptrCast(@alignCast(page.realm.getV8WrapperCacheStorage() orelse return error.NoCache));
    page.fullGC();

    const Kind = enum { traced, weak_handle, weak_handle_young };
    for ([_]Kind{ .traced, .weak_handle, .weak_handle_young }) |kind| {
        const got = try page.evalOwned(switch (kind) {
            .traced => "globalThis.h = new URLSearchParams('a=b'); h",
            .weak_handle, .weak_handle_young => "globalThis.h = new Event('x'); h",
        });
        const instance = protocol.convertToPlatformObject(page.realm, got.value) orelse return error.NoInstance;
        const handle = cache.get(instance) orelse return error.NotCached;
        const entered = page.enter();
        defer page.leave(entered);
        const watch = ffi.v8_test_PlatformAnchorWatch_New(page.isolate(), handle) orelse return error.NoAnchor;
        defer ffi.v8_test_PlatformAnchorWatch_Delete(watch);
        // The cache took the wrapper: its anchor names the cache's record.
        try testing.expectEqual(@as(c_int, 2), ffi.v8_test_PlatformAnchorWatch_Names(watch));
        got.release();
        try page.run("globalThis.h = null; 0");
        const pending_before = cache.pendingFinalizerCount();

        // Script holds the wrapper no more; this frame holds its anchor's address through a collection that
        // scans the stack.
        var in_frame: usize = ffi.v8_test_PlatformAnchorWatch_Address(watch);
        try testing.expect(in_frame != 0);
        if (kind == .weak_handle_young) {
            // The wrapper dies in a YOUNG collection first, which does not collect the C++ heap: its Global's
            // first pass severs the anchor there and lists it for its free at the agent's drain - which does
            // not run here (no pump), so the anchor is still an object when the full collection below scans
            // the stack and traces it.
            const full_before = page.fullCollections();
            ffi.v8_test_Isolate_MinorGC(page.isolate(), 4);
            if (page.fullCollections() != full_before) {
                std.debug.print("a full collection ran among the young ones: nothing was read\n", .{});
                return error.TestInconclusive;
            }
            try testing.expect(cache.get(instance) == null);
            try testing.expectEqual(pending_before + 1, cache.pendingFinalizerCount());
            try testing.expectEqual(@as(c_int, 0), ffi.v8_test_PlatformAnchorWatch_Names(watch));
            // The record is freed (its finalizer, run by its cache; the agent's drain, which would free the
            // anchor ahead of the collector, has not run): the anchor outlives it.
            cache.finalizePendingForTest();
            try testing.expectEqual(pending_before, cache.pendingFinalizerCount());
        }
        collectScanningStack(page.isolate(), &in_frame);
        const names = ffi.v8_test_PlatformAnchorWatch_Names(watch);
        if (names == -1) {
            std.debug.print("the scan of the stack did not keep the anchor ({s}): nothing was read\n", .{@tagName(kind)});
            return error.TestInconclusive;
        }
        switch (kind) {
            .traced => {
                // The anchor kept its wrapper: the cache still holds it, and the anchor still names its record.
                try testing.expect(cache.get(instance) != null);
                try testing.expectEqual(pending_before, cache.pendingFinalizerCount());
                try testing.expectEqual(@as(c_int, 2), names);
            },
            .weak_handle => {
                // The wrapper died under the anchor: the record waits for its finalizer, and the anchor - which
                // outlives it - names nothing from here.
                try testing.expect(cache.get(instance) == null);
                try testing.expectEqual(pending_before + 1, cache.pendingFinalizerCount());
                if (an_anchor_that_outlives_its_wrapper_names_no_record) {
                    try testing.expectEqual(@as(c_int, 0), names);
                } else {
                    try testing.expectEqual(@as(c_int, 2), names);
                }
                // The agent's safe point frees the Event and the record.
                while (ffi.v8_Platform_PumpMessageLoop(page.isolate())) {}
                _ = ffi.v8_Isolate_RunQueuedFinalizers(page.isolate());
                try testing.expectEqual(pending_before, cache.pendingFinalizerCount());
                // The anchor is traced again, with its record gone.
                if (an_anchor_that_outlives_its_wrapper_names_no_record) {
                    collectScanningStack(page.isolate(), &in_frame);
                    try testing.expectEqual(@as(c_int, 0), ffi.v8_test_PlatformAnchorWatch_Names(watch));
                }
            },
            .weak_handle_young => {
                // The anchor was traced with its record gone: it names nothing, and does so again.
                try testing.expectEqual(@as(c_int, 0), names);
                collectScanningStack(page.isolate(), &in_frame);
                try testing.expectEqual(@as(c_int, 0), ffi.v8_test_PlatformAnchorWatch_Names(watch));
            },
        }

        // Out of the frame, the next collection takes the anchor (and the traced wrapper with it).
        in_frame = 0;
        std.mem.doNotOptimizeAway(&in_frame);
        ffi.v8_test_Isolate_CollectWithoutDrain(page.isolate());
        try testing.expectEqual(@as(c_int, -1), ffi.v8_test_PlatformAnchorWatch_Names(watch));
        while (ffi.v8_Platform_PumpMessageLoop(page.isolate())) {}
        _ = ffi.v8_Isolate_RunQueuedFinalizers(page.isolate());
        try testing.expect(cache.get(instance) == null);
        try testing.expectEqual(pending_before, cache.pendingFinalizerCount());
    }
}

test "a wrapper the cache holds by a weak handle costs no callback record: the handle's parameter is the wrapper's anchor" {
    // Until lane wrap2 the weak v8::Global of such a record - an Event's, a legacy platform object's proxy's, a
    // wrapper the binding changed - was armed as every weak Global of the adapter is: a 48-byte callback record
    // from malloc and a node in the adapter's process-wide armed-handle map, taken under its mutex at every arm
    // and every death (about 112 B per kept wrapper: gc_bench, tmp/plans/wrap1-evidence/b3-meas4-kept-l.out).
    // Now the Global's parameter is the wrapper's anchor, which names the record: nothing is allocated for the
    // arm. Node keeps a weak object the same way - the owner itself is the parameter (src/base_object.cc
    // BaseObject::MakeWeak, nodejs/node 2fb168f7) - and V8's WeakCallbackInfo<T> is declared for a T on the C++
    // heap (include/v8-weak-callback-info.h: ConditionalStackAllocatedBase<T>). The count is the process's:
    // tests-v8 runs a test in a process of its own.
    const page = try Page.open();
    defer page.close();
    try page.run(objects);
    const n = 2000;
    const shapes = [_]struct { name: []const u8, make: []const u8, weak_records: f64 }{
        .{ .name = "an Event (born with an own property)", .make = "o.keep.push(new Event('x'))", .weak_records = 1 },
        .{ .name = "a URL whose searchParams was read (the binding's edge: the URL and its URLSearchParams)", .make = "{ const u = new URL('https://wrap1.test/?a=1'); void u.searchParams; o.keep.push(u); }", .weak_records = 2 },
        .{ .name = "a div's HTMLCollection (behind a proxy)", .make = "o.keep.push(doc2.createElement('div').children)", .weak_records = 1 },
        .{ .name = "a URLSearchParams (a traced reference: never had one)", .make = "o.keep.push(new URLSearchParams('a=b'))", .weak_records = 0 },
    };
    var wrong: usize = 0;
    for (shapes) |shape| {
        try page.run("o.keep = []; globalThis.doc2 = new Document().implementation.createHTMLDocument(''); 0");
        var source: [320]u8 = undefined;
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < 8; i++) {s}; o.keep.length", .{shape.make}));
        page.fullGC();
        const before = try page.counter("live_weak_callback_data");
        const entries_before = try page.counter("wrapper_cache_entries");
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {s}; o.keep.length", .{ n, shape.make }));
        const records = @as(f64, @floatFromInt(try page.counter("live_weak_callback_data") - before)) / @as(f64, n);
        const entries = @as(f64, @floatFromInt(try page.counter("wrapper_cache_entries") - entries_before)) / @as(f64, n);
        std.debug.print("{s}: {d:.2} callback records per kept object ({d:.2} cache entries; {d:.0} of them held by a weak handle)\n", .{ shape.name, records, entries, shape.weak_records });
        // Every object is cached, and none has a callback record.
        if (entries < shape.weak_records - 0.01) wrong += 1;
        if (records > 0.01) wrong += 1;
        try page.run("o.keep = null; 0");
        page.fullGC();
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

test "a wrapper held by a weak handle that the cache keeps survives both kinds of collection, and is collected once released: by a young collection while it is young, by a full one after it survived" {
    // Pending activity (engine.keepPlatformObjectAlive) makes a record's weak Global strong and its release arms
    // it again (wrapper_cache.zig makeStrong, makeWeak; v8_wrapper.cpp v8_WrapperCell_Disarm, v8_WrapperCell_ArmWeak)
    // - with the wrapper's anchor as the arm's parameter, each time. A Global that stayed strong after the
    // release would keep the wrapper and its instance until the realm's end.
    const WrapperCache = @import("v8").WrapperCache;
    const page = try Page.open();
    defer page.close();
    const cache: *WrapperCache = @ptrCast(@alignCast(page.realm.getV8WrapperCacheStorage() orelse return error.NoCache));
    page.fullGC();
    const records_before = try page.counter("live_weak_callback_data");

    // KEPT THROUGH COLLECTIONS, THEN RELEASED. The wrapper survives a full collection while it is held, so V8
    // has moved it to the old generation: from there only a full collection takes it, whatever holds it (a
    // young collection processes the weak handles of young objects alone: 15.7.112.43
    // src/handles/global-handles.cc ProcessWeakYoungObjects walks `young_nodes_`).
    {
        const got = try page.evalOwned("new Event('x')");
        const instance = protocol.convertToPlatformObject(page.realm, got.value) orelse return error.NoInstance;
        const generation = runtime.SlabAllocator.generationOf(instance);
        protocol.keepPlatformObjectAlive(instance);
        protocol.keepPlatformObjectAlive(instance);
        got.release();

        // Nothing of script's holds it; the cache does.
        try page.minorGC(4);
        page.fullGC();
        const handle = cache.get(instance) orelse return error.NotCached;
        try testing.expect(!ffi.v8_Global_IsEmpty(@ptrCast(handle)));
        try testing.expect(!ffi.v8_Global_IsWeak(@ptrCast(handle)));
        try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(instance));

        // One of two keeps ended: still held, through a full collection too.
        protocol.releasePlatformObject(instance);
        try testing.expect(!ffi.v8_Global_IsWeak(@ptrCast(handle)));
        page.fullGC();
        try testing.expectEqual(handle, cache.get(instance) orelse return error.NotCached);

        // The last keep ended: the same handle is weak again, and a full collection takes the wrapper.
        protocol.releasePlatformObject(instance);
        try testing.expectEqual(handle, cache.get(instance) orelse return error.NotCached);
        try testing.expect(ffi.v8_Global_IsWeak(@ptrCast(handle)));
        page.fullGC();
        try testing.expect(cache.get(instance) == null);
        try testing.expect(generation != runtime.SlabAllocator.generationOf(instance));
    }

    // KEPT AND RELEASED WHILE YOUNG. No collection runs while it is held, so the wrapper is still in the young
    // generation when the arm is made again: a young collection takes it (an Event's wrapper is no unmodified
    // API object: only a weak Global's first pass finds it dead there).
    var attempt: usize = 0;
    while (attempt < 4) : (attempt += 1) {
        const collections_before = page.fullCollections() + @as(u64, @intCast(try page.counter("minor_gc_count")));
        const got = try page.evalOwned("new Event('x')");
        const instance = protocol.convertToPlatformObject(page.realm, got.value) orelse return error.NoInstance;
        const generation = runtime.SlabAllocator.generationOf(instance);
        protocol.keepPlatformObjectAlive(instance);
        const handle = cache.get(instance) orelse return error.NotCached;
        try testing.expect(!ffi.v8_Global_IsWeak(@ptrCast(handle)));
        protocol.releasePlatformObject(instance);
        try testing.expect(ffi.v8_Global_IsWeak(@ptrCast(handle)));
        got.release();
        // A collection V8 chose to run meanwhile may have promoted the wrapper: read again.
        if (page.fullCollections() + @as(u64, @intCast(try page.counter("minor_gc_count"))) != collections_before) continue;

        const full_before = page.fullCollections();
        try page.minorGC(4);
        if (page.fullCollections() != full_before) continue;
        try testing.expect(cache.get(instance) == null);
        try testing.expect(generation != runtime.SlabAllocator.generationOf(instance));
        // Arming, disarming and both deaths left no callback record behind.
        try testing.expect(try page.counter("live_weak_callback_data") <= records_before);
        return;
    }
    std.debug.print("a collection ran inside each of {d} attempts: the young case was not read\n", .{attempt});
    return error.TestInconclusive;
}

test "what the instances behind live non-node wrappers hold is in the figure V8 is told, by one function of the instance" {
    // A wrapper is 16 B of V8's heap and keeps an instance V8 cannot see; V8 schedules collections by what it
    // sees. The adapter keeps what the instances behind its LIVE non-node wrappers hold - each one's slab slot,
    // state block, cache record and internal state block - and tells V8 through its own ExternalMemoryAccounter
    // once 128 KB wait, at the agent's safe point (v8_wrapper.cpp, "What the instances behind non-node wrappers
    // hold"). Until lane dm3 this was an account of allocation, forgotten as each full collection began; what it
    // is now, and when it falls, is tests/v8/dm3_instance_figure_test.zig's subject. This pins the amount.
    const page = try Page.open();
    defer page.close();
    const n = 6000;
    try page.run("for (let i = 0; i < 64; i++) void new URLSearchParams('a=b'); 0");

    var attempt: usize = 0;
    while (attempt < 4) : (attempt += 1) {
        page.fullGC();
        const base = try page.counter("wrapped_instance_bytes_live");
        const full_before = page.fullCollections();
        var source: [160]u8 = undefined;
        try page.run(try std.fmt.bufPrint(&source, "globalThis.keep = []; for (let i = 0; i < {d}; i++) keep.push(new URLSearchParams('a=b')); 0", .{n}));
        const live = try page.counter("wrapped_instance_bytes_live") - base;
        const reported = try page.counter("wrapped_instance_bytes_reported");
        // A full collection V8 chose to run meanwhile moved what this reads: read again.
        if (page.fullCollections() != full_before) continue;
        std.debug.print("{d} wrapped URLSearchParams: {d} B in the figure ({d:.1} each), {d} B reported to V8\n", .{ n, live, @as(f64, @floatFromInt(live)) / @as(f64, n), reported });
        // At least the slab slot and the cache's record each (64 B), and no more than a page each.
        try testing.expect(live >= n * 64 and live <= n * 4096);
        // Reported in steps of 128 KB or more, never a step behind the figure - with what died since the last
        // full collection, which V8 is still told (tests/v8/dm3_instance_figure_test.zig).
        const dead = try page.counter("wrapped_instance_bytes_dead");
        try testing.expect(reported >= 128 * 1024 and reported <= base + live + dead);
        try testing.expect(base + live + dead - reported < 128 * 1024 + 4096);
        try page.run("globalThis.keep = null; 0");
        page.fullGC();
        // Dropped and collected, they are out of it, and V8 holds no more than a step over the figure.
        try testing.expect(try page.counter("wrapped_instance_bytes_live") < base + 4096);
        try testing.expect(try page.counter("wrapped_instance_bytes_reported") < base + 4096 + 128 * 1024);

        // What V8 is told per object of three shapes (the merge report quotes these). The figure is ONE
        // function of the instance (wrapper_cache.instanceHeldBytes: its slab slot, its generated State block,
        // the cache's record, and the internal state block its State names), so what a loop adds is that
        // function's answer for one of its objects, a thousand times - and nothing a call site computes.
        // An Event's internal state - its dispatch state, dom.event_dispatch.EventState - is a block of its
        // own, so V8 is told at least that: told 112 B of the 1.2 KB an Event held while that block was
        // 1,024 B (it is 88 B since lane ev1), V8 let 650,000 dropped Events end 13% over main on server1
        // (gc_bench, 2026-11-15; wrapper_cache.zig `instanceHeldBytes`).
        const instanceHeldBytes = @import("v8").wrapper_cache_mod.instanceHeldBytes;
        const shapes = [_]struct { name: []const u8, make: []const u8, at_least: usize }{
            .{ .name = "an Event", .make = "new Event('x')", .at_least = 64 + @sizeOf(dom.event_dispatch.EventState) },
            .{ .name = "a URLSearchParams", .make = "new URLSearchParams('a=b')", .at_least = 64 },
            .{ .name = "a div's attributes collection (the NamedNodeMap alone: a div is counted by the host)", .make = "doc2.createElement('div').attributes", .at_least = 64 },
        };
        try page.run("globalThis.doc2 = new Document(); 0");
        for (shapes) |shape| {
            var one_source: [160]u8 = undefined;
            const one = try page.evalOwned(try std.fmt.bufPrint(&one_source, "globalThis.one = {s}; one", .{shape.make}));
            const held: i64 = @intCast(instanceHeldBytes(protocol.convertToPlatformObject(page.realm, one.value) orelse return error.NoInstance));
            one.release();
            try page.run("globalThis.one = null; 0");
            page.fullGC();
            const before_full = page.fullCollections();
            const before = try page.counter("wrapped_instance_bytes_live");
            try page.run(try std.fmt.bufPrint(&source, "globalThis.keep = []; for (let i = 0; i < 1000; i++) keep.push({s}); 0", .{shape.make}));
            const told = try page.counter("wrapped_instance_bytes_live") - before;
            try page.run("globalThis.keep = null; 0");
            if (page.fullCollections() != before_full) continue;
            std.debug.print("V8 is told {d} B for {s}\n", .{ held, shape.name });
            // At least the slab slot, the cache's record and the shape's internal state; no more than a page.
            try testing.expect(held >= @as(i64, @intCast(shape.at_least)) and held <= 4096);
            // Each of the thousand, and no other wrapper's worth beyond a page (the loop's own first wraps).
            try testing.expect(told >= 1000 * held and told < 1000 * held + 4096);
        }
        return;
    }
    std.debug.print("a full collection ran in each of {d} attempts: nothing was read\n", .{attempt});
    return error.TestInconclusive;
}

test "a State's internal state blocks are read from its types, and counted only while they exist" {
    // What the account of a wrapped instance adds for its impl's internal state (interface_bindings
    // `stateBlocksOf`, `stateBlockBytes`): one block for each level of the State's inheritance chain that
    // keeps that state in a block of its own, counted while the level's pointer is set. A level with an empty
    // internal state names nothing. No impl is named: the State's types say it.
    const bindings = @import("v8").interface_bindings;
    const Big = struct { bytes: [200]u8 };
    const Small = struct { word: u64 };
    const Empty = struct {};
    const Root = runtime.FlattenedState(null, &.{}, struct { a: u32 = 0, _internal: ?*Big = null });
    const Mid = runtime.FlattenedState(Root, &.{}, struct { _internal: ?*Empty = null });
    const Leaf = runtime.FlattenedState(Mid, &.{}, struct { b: u8 = 0, _internal: ?*Small = null });

    const blocks = comptime bindings.stateBlocksOf(Leaf);
    try testing.expectEqual(@as(usize, 2), blocks.len);
    try testing.expectEqual(@as(usize, 1), comptime bindings.stateBlocksOf(Root).len);
    try testing.expectEqual(@as(usize, 1), comptime bindings.stateBlocksOf(Mid).len);

    var state = std.mem.zeroes(Leaf);
    try testing.expectEqual(@as(usize, 0), bindings.stateBlockBytes(blocks, &state));
    var small: Small = .{ .word = 1 };
    state.own._internal = &small;
    try testing.expectEqual(@as(usize, @sizeOf(Small)), bindings.stateBlockBytes(blocks, &state));
    var big: Big = .{ .bytes = @splat(0) };
    state.base.base.own._internal = &big;
    try testing.expectEqual(@as(usize, @sizeOf(Small) + @sizeOf(Big)), bindings.stateBlockBytes(blocks, &state));
    state.own._internal = null;
    try testing.expectEqual(@as(usize, @sizeOf(Big)), bindings.stateBlockBytes(blocks, &state));

    // The generated States: an Event's one block is its dispatch state, and an interface that inherits from
    // Event names that block too.
    const event_blocks = comptime bindings.stateBlocksOf(interfaces.Event.State);
    try testing.expectEqual(@as(usize, 1), event_blocks.len);
    try testing.expectEqual(@as(u32, @sizeOf(dom.event_dispatch.EventState)), event_blocks[0].bytes);
    var inherited: usize = 0;
    for (comptime bindings.stateBlocksOf(interfaces.CustomEvent.State)) |block| {
        if (block.bytes == @sizeOf(dom.event_dispatch.EventState)) inherited += 1;
    }
    try testing.expectEqual(@as(usize, 1), inherited);
    try testing.expectEqual(@as(usize, 1), bindings.wrapperFactsOf("Event").state_blocks.len);
    try testing.expect(bindings.wrapperFactsOf("Event").born_changed);
    // A name no interface has: an ordinary wrapper with no block.
    try testing.expectEqual(@as(usize, 0), bindings.wrapperFactsOf("NoSuchInterface").state_blocks.len);
    try testing.expect(!bindings.wrapperFactsOf("NoSuchInterface").born_changed);
}
