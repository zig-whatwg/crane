//! A platform object's wrapper on V8 15.7 keeps ONE internal field, its instance (lane v8up b3b, "A0";
//! tmp/plans/object-wrap-design.md 3.2-3.3, tmp/plans/v8-global-object-design.md 3.3).
//!
//! Field 1 held a WrapperTypeInfo for dom_type_info's 24 interfaces, which the receiver checks walked before
//! the real brand check: whether the instance's state ancestry has the interface's State (`conv.implements`,
//! binding_plumbing.operationBody step 2.4, the accessors' implementsInterface) - WebIDL 3.7.6 "If O is not a
//! platform object that implements the interface, throw a TypeError" and "create an operation function" step
//! 2.4. That check is per instance, so it holds across realms and whatever an object's prototype says. On
//! 15.7 every aligned pointer in an internal field allocates a cppgc EmbedderDataSlotWrapper (V8 d04704a20fc),
//! so the second pointer cost a heap object per typed wrapper and checked nothing the ancestry does not.
//! Blink's wrapper keeps one CppHeap pointer (Object::Wrap) and its type check is the tag range; Crane's is the
//! ancestry (design 3.3).
//!
//! The first two tests pin what script observes of the brand check - a receiver of another interface is a
//! TypeError for an accessor, a method and a constructor's result, between two interfaces, typed (Crane-made
//! wrappers had field 1) or not (constructed ones never had it), and across two realms - and pass before and
//! after. The last two are the RED: one field, and one cppgc box per kept typed wrapper.

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

const no_hooks: protocol.HostHooks = .{};

fn windowRealm(agent: *protocol.Agent) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://v8up.test",
        .global_this = .new_window_proxy,
        .create_global_object = WindowHost.createGlobalObject,
    });
}

fn evalOwned(r: runtime.Context, source: []const u8) !protocol.Owned {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScript(r, .{ .utf8 = source }, "", null, reports.reporter());
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expectOk(r: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
    try testing.expectEqualStrings("ok", got);
}

/// The objects every test uses, on `globalThis.o`: wrappers Crane made for an instance (a node, a non-node -
/// both kinds carried field 1 for dom_type_info's interfaces) and a constructor's results (which never did).
const objects =
    \\const doc = new Document().implementation.createHTMLDocument("");
    \\globalThis.o = {
    \\  div: doc.createElement("div"),            // a node wrapper Crane made (HTMLDivElement)
    \\  text: doc.createTextNode("t"),            // a node wrapper Crane made (Text)
    \\  made: doc.createEvent("Event"),           // a non-node wrapper Crane made (Event)
    \\  url: new URL("https://v8up.test/?a=1"),   // a constructor's result
    \\  event: new Event("x"),                    // a constructor's result
    \\  // A constructor's result whose prototype is another interface's (NewTarget's): the brand is the instance.
    \\  disguised: Reflect.construct(URL, ["https://v8up.test/"], Event),
    \\};
    \\o.params = o.url.searchParams;              // a non-node wrapper Crane made (URLSearchParams)
    \\"made"
;

const checks =
    \\const failures = [];
    \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
;

test "a receiver of another interface is a TypeError for an accessor, a method and a constructor's result" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    (try evalOwned(realm, objects)).release();

    try expectOk(realm, checks ++
        \\function throwsTypeError(name, f) {
        \\  try { f(); failures.push(name + ": did not throw"); }
        \\  catch (e) { if (!(e instanceof TypeError)) failures.push(name + ": threw " + e); }
        \\}
        \\const get = (I, n) => Object.getOwnPropertyDescriptor(I.prototype, n).get;
        \\const set = (I, n) => Object.getOwnPropertyDescriptor(I.prototype, n).set;
        \\// Accessors: typed receivers of another interface, untyped ones, both ways.
        \\throwsTypeError("URL href on a div", () => get(URL, "href").call(o.div));
        \\throwsTypeError("Node nodeName on a URL", () => get(Node, "nodeName").call(o.url));
        \\throwsTypeError("Event type on a URLSearchParams", () => get(Event, "type").call(o.params));
        \\throwsTypeError("Node nodeName on createEvent's Event", () => get(Node, "nodeName").call(o.made));
        \\throwsTypeError("Element tagName on a Text", () => get(Element, "tagName").call(o.text));
        \\throwsTypeError("Event type on a div", () => get(Event, "type").call(o.div));
        \\throwsTypeError("Element id setter on a Text", () => set(Element, "id").call(o.text, "x"));
        \\throwsTypeError("URLSearchParams size on a constructed Event", () => get(URLSearchParams, "size").call(o.event));
        \\// Methods.
        \\throwsTypeError("URLSearchParams append on a constructed Event", () => URLSearchParams.prototype.append.call(o.event, "a", "b"));
        \\throwsTypeError("Node appendChild on a URLSearchParams", () => Node.prototype.appendChild.call(o.params, o.text));
        \\throwsTypeError("Element getAttribute on a Text", () => Element.prototype.getAttribute.call(o.text, "id"));
        \\throwsTypeError("Event preventDefault on a div", () => Event.prototype.preventDefault.call(o.div));
        \\throwsTypeError("URL toJSON on createEvent's Event", () => URL.prototype.toJSON.call(o.made));
        \\// A constructor's result with another interface's prototype is still what its constructor made.
        \\check("the disguised URL has Event.prototype", Object.getPrototypeOf(o.disguised), Event.prototype);
        \\throwsTypeError("Event type on a URL with Event.prototype", () => o.disguised.type);
        \\throwsTypeError("Event preventDefault on a URL with Event.prototype", () => o.disguised.preventDefault());
        \\check("URL href on it", get(URL, "href").call(o.disguised), "https://v8up.test/");
        \\// The right receivers, an ancestor interface's members included.
        \\check("Node nodeName on a div", get(Node, "nodeName").call(o.div), "DIV");
        \\check("Element tagName on a div", get(Element, "tagName").call(o.div), "DIV");
        \\check("EventTarget dispatchEvent on a div", EventTarget.prototype.dispatchEvent.call(o.div, new Event("y")), true);
        \\check("Node nodeName on a Text", get(Node, "nodeName").call(o.text), "#text");
        \\check("Event type on createEvent's Event", get(Event, "type").call(o.made), "");
        \\check("Event type on a constructed Event", get(Event, "type").call(o.event), "x");
        \\check("URLSearchParams get", URLSearchParams.prototype.get.call(o.params, "a"), "1");
        \\check("URL href on a constructed URL", get(URL, "href").call(o.url), "https://v8up.test/?a=1");
        \\failures.join("; ") || "ok"
    );
}

test "another realm's accessor and method take this realm's object of their interface and throw their own realm's TypeError for another" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const here = try windowRealm(agent);
    defer protocol.destroyWindowRealm(here, .global_detached);
    const there = try windowRealm(agent);
    defer protocol.destroyWindowRealm(there, .global_detached);
    (try evalOwned(here, objects)).release();
    {
        const members = try evalOwned(there,
            \\const get = (I, n) => Object.getOwnPropertyDescriptor(I.prototype, n).get;
            \\({ href: get(URL, "href"), nodeName: get(Node, "nodeName"), type: get(Event, "type"),
            \\   append: URLSearchParams.prototype.append, getAttribute: Element.prototype.getAttribute,
            \\   TypeError })
        );
        defer members.release();
        const global = try evalOwned(here, "globalThis");
        defer global.release();
        try protocol.setProperty(here, global.value, "other", members.value);
    }

    try expectOk(here, checks ++
        \\function throwsTheirTypeError(name, f) {
        \\  try { f(); failures.push(name + ": did not throw"); }
        \\  catch (e) {
        \\    if (!(e instanceof other.TypeError)) failures.push(name + ": threw " + e + (e instanceof TypeError ? " (this realm's)" : ""));
        \\  }
        \\}
        \\check("their href on our URL", other.href.call(o.url), "https://v8up.test/?a=1");
        \\check("their nodeName on our div", other.nodeName.call(o.div), "DIV");
        \\check("their type on our createEvent Event", other.type.call(o.made), "");
        \\other.append.call(o.params, "b", "2");
        \\check("their append on our URLSearchParams", o.params.get("b"), "2");
        \\check("their getAttribute on our div", other.getAttribute.call(o.div, "id"), null);
        \\throwsTheirTypeError("their href on our div", () => other.href.call(o.div));
        \\throwsTheirTypeError("their nodeName on our URL", () => other.nodeName.call(o.url));
        \\throwsTheirTypeError("their type on our URLSearchParams", () => other.type.call(o.params));
        \\throwsTheirTypeError("their type on our disguised URL", () => other.type.call(o.disguised));
        \\throwsTheirTypeError("their append on our Event", () => other.append.call(o.event, "a", "b"));
        \\throwsTheirTypeError("their getAttribute on our Text", () => other.getAttribute.call(o.text, "id"));
        \\failures.join("; ") || "ok"
    );
    try expectOk(here, "delete globalThis.other ? 'ok' : 'not deleted'");
}

test "a platform object's wrapper has one internal field, its instance" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    (try evalOwned(realm, objects)).release();

    const names = [_][]const u8{ "div", "text", "made", "url", "event", "disguised", "params" };
    var wrong: usize = 0;
    for (names) |name| {
        var source: [64]u8 = undefined;
        const got = try evalOwned(realm, try std.fmt.bufPrint(&source, "o.{s}", .{name}));
        defer got.release();
        const object: *ffi.Object = @ptrCast(@alignCast(got.value.handle.ptr));
        const count = ffi.v8_Object_InternalFieldCount(object);
        const instance = if (count >= 1) ffi.v8_Object_GetAlignedPointerFromInternalField(object, 0) else null;
        if (count != 1 or instance == null) {
            std.debug.print("o.{s}: {d} internal fields, field 0 {s}\n", .{ name, count, if (instance == null) "empty" else "set" });
            wrong += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

/// The agent's CppHeap bytes after a full collection, taken inside the realm.
const HeapBytes = struct {
    agent: *protocol.Agent,
    bytes: usize = 0,

    fn of(realm: runtime.Context, agent: *protocol.Agent) !usize {
        var self: HeapBytes = .{ .agent = agent };
        try protocol.runInRealm(realm, steps, &self);
        return self.bytes;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *HeapBytes = @ptrCast(@alignCast(data.?));
        protocol.requestGarbageCollection(self.agent);
        // The adapter's Agent is the isolate (protocol.zig isolateOf).
        self.bytes = ffi.v8_Isolate_CppHeapUsedBytes(@ptrCast(@alignCast(self.agent)));
    }
};

test "a kept wrapper Crane made costs one cppgc slot wrapper, node and non-node alike" {
    // design 3.3 / object-wrap-design 3.1: one aligned pointer in an internal field is one cppgc
    // EmbedderDataSlotWrapper of 24 B with its header; field 1 was a second for every typed wrapper.
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    (try evalOwned(realm, objects)).release();
    const n = 4000;

    const kinds = [_]struct { name: []const u8, make: []const u8 }{
        .{ .name = "div (node)", .make = "o.keep.push(doc2.createElement('div'))" },
        .{ .name = "createEvent's Event (non-node)", .make = "o.keep.push(doc2.createEvent('Event'))" },
    };
    for (kinds) |kind| {
        (try evalOwned(realm, "o.keep = []; globalThis.doc2 = new Document().implementation.createHTMLDocument(''); 0")).release();
        const before = try HeapBytes.of(realm, agent);
        var source: [160]u8 = undefined;
        (try evalOwned(realm, try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) {s}; o.keep.length", .{ n, kind.make }))).release();
        const after = try HeapBytes.of(realm, agent);
        const per = @as(f64, @floatFromInt(after -| before)) / @as(f64, n);
        std.debug.print("{s}: {d:.1} B of CppHeap per kept wrapper ({d} -> {d})\n", .{ kind.name, per, before, after });
        try testing.expect(per < 34.0);
        (try evalOwned(realm, "o.keep = null; 0")).release();
    }
}

test "ffi.ArgumentRead has the C++ side's layout" {
    // It crosses the FFI by pointer (v8_FunctionCallbackInfo_ReadArgument fills it); A0 took a field out of both.
    try testing.expectEqual(ffi.v8_ArgumentRead_Size(), @sizeOf(ffi.ArgumentRead));
}
