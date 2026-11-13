//! A legacy platform object's proxy shares its realm's handler (lane wrap1 b2, the integrator's ruling of
//! 2026-11-13 on the batch's finding 1).
//!
//! A legacy platform object with named properties - an HTMLCollection, an HTMLFormControlsCollection, an
//! HTMLOptionsCollection, a NamedNodeMap, a Storage, a CSSStyleDeclaration (template_registry.zig
//! legacy_platform_objects) - is wrapped in a Proxy so that [[OwnPropertyKeys]] answers in WebIDL's order
//! (3.9.6). The proxy's handler was made afresh for every wrapper:
//! an object and ten FunctionTemplates with their Functions, 3,860 B of V8's heap per wrapper (gc_bench, lane
//! wrap1 b2 step 0: a kept NamedNodeMap 4,800 B resident; 400,000 of them reached V8's heap limit). The handler
//! holds nothing of its proxy: ES 10.5 calls every trap with the target as its first argument, and the traps
//! read it there. So one handler per realm serves every proxy of the realm (two: the "set" trap is told whether
//! its interface has a named property setter).
//!
//! Script cannot tell: no ES operation returns a proxy's [[ProxyHandler]], and the traps are API functions, which
//! V8 leaves out of stack traces (15.7.112.43 src/execution/isolate.cc IsNotHidden: an API function is hidden
//! unless --experimental-stack-trace-frames, off by default and not in Crane's flags) - pinned below, with
//! `caller`. A debugger can read [[Handler]] (the repl's inspector session), so the shared handler is frozen
//! and has a null prototype: nothing reached that way can change another object's traps. The null prototype
//! also closes a hole the per-wrapper handler had: it inherited from %Object.prototype%, and a proxy looks its
//! traps up with GetMethod, so `Object.prototype.get = f` became every legacy platform object's [[Get]] trap.
//!
//! Blink has no such proxy: its bindings generator installs named and indexed property interceptors on the
//! interface's instance template (third_party/blink/renderer/bindings/scripts/bind_gen/interface.py), which
//! costs nothing per wrapper - and takes V8's own key order, a named interceptor's names after the object's own
//! string keys (KeyAccumulator::CollectOwnPropertyNames), where WebIDL and WPT put them before.
//!
//! The collections are V8's own. The file shares tests/v8's process and makes its own agent per test.

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

fn evalOwned(realm: runtime.Context, source: []const u8) !protocol.Owned {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expectOk(realm: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
    try testing.expectEqualStrings("ok", got);
}

/// V8's used heap bytes after two requested full collections.
fn heapUsed(agent: *protocol.Agent) usize {
    // The adapter's Agent is the isolate (protocol.zig isolateOf).
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const entered = ffi.v8_Isolate_GetCurrent() != isolate;
    if (entered) ffi.v8_Isolate_Enter(isolate);
    defer if (entered) ffi.v8_Isolate_Exit(isolate);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    var used: usize = 0;
    ffi.v8_Isolate_GetHeapUsage(isolate, &used, null, null);
    return used;
}

const setup =
    \\globalThis.doc = new Document().implementation.createHTMLDocument("");
    \\globalThis.failures = [];
    \\globalThis.check = (name, got, want) => { if (got !== want) failures.push(name + ": " + String(got)); };
    \\globalThis.element = () => { const e = doc.createElement("div"); e.setAttribute("data-k", "v"); e.appendChild(doc.createElement("p")); return e; };
    \\globalThis.form = () => { const f = doc.createElement("form"); f.appendChild(doc.createElement("input")).name = "q"; return f; };
    \\globalThis.select = () => { const s = doc.createElement("select"); s.appendChild(doc.createElement("option")); return s; };
    \\"made"
;

test "a kept legacy platform object costs no handler of its own" {
    // Each row keeps an element's object, and so the element (the object's edge to it): two wrappers, a proxy
    // and their edges - under 300 B of V8's heap. With a handler per proxy it was 3,900.
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    (try evalOwned(realm, setup)).release();
    const n = 2000;

    const kinds = [_]struct { name: []const u8, make: []const u8 }{
        .{ .name = "NamedNodeMap (el.attributes)", .make = "element().attributes" },
        .{ .name = "HTMLCollection (el.children)", .make = "element().children" },
        .{ .name = "HTMLFormControlsCollection (form.elements)", .make = "form().elements" },
        .{ .name = "HTMLOptionsCollection (select.options)", .make = "select().options" },
        // Not behind a proxy (its interface is not in legacy_platform_objects): the same before and after.
        .{ .name = "DOMStringMap (el.dataset), no proxy", .make = "element().dataset" },
    };
    var wrong: usize = 0;
    for (kinds) |kind| {
        var source: [200]u8 = undefined;
        // The array at its full length first, and the kind's shapes made once, so the difference is the objects'.
        (try evalOwned(realm, try std.fmt.bufPrint(&source, "globalThis.keep = new Array({d}); void {s}; 0", .{ n, kind.make }))).release();
        const before = heapUsed(agent);
        (try evalOwned(realm, try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) keep[i] = {s}; keep.length", .{ n, kind.make }))).release();
        const after = heapUsed(agent);
        const per = @as(f64, @floatFromInt(after -| before)) / @as(f64, n);
        std.debug.print("{s}: {d:.1} B of V8 heap per kept object ({d} -> {d})\n", .{ kind.name, per, before, after });
        if (per > 300.0 or per < 40.0) wrong += 1;
        (try evalOwned(realm, "globalThis.keep = null; 0")).release();
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

test "the proxies of a realm share one handler, frozen and with no prototype; another realm has its own" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const here = try windowRealm(agent);
    defer protocol.destroyWindowRealm(here, .global_detached);
    const there = try windowRealm(agent);
    defer protocol.destroyWindowRealm(there, .global_detached);
    (try evalOwned(here, setup)).release();
    (try evalOwned(there, setup)).release();

    const Handler = struct {
        /// The handler of the proxy `source` evaluates to in `realm`, OWNED (v8_Value_Dispose).
        fn of(realm: runtime.Context, source: []const u8) !*ffi.Value {
            const got = try evalOwned(realm, source);
            defer got.release();
            const object: *ffi.Object = @ptrCast(@alignCast(got.value.handle.ptr));
            try testing.expect(ffi.v8_Value_IsProxy(@ptrCast(object)));
            return ffi.v8_Proxy_GetHandler(object) orelse error.NoHandler;
        }

        /// The handler of a new legacy platform object proxy made in `realm` around a plain object, for an
        /// interface with (`named_setter`) or without a named property setter; OWNED.
        fn ofNew(realm: runtime.Context, named_setter: bool) !*ffi.Value {
            const target = try evalOwned(realm, "({})");
            defer target.release();
            const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx orelse return error.NoContext));
            const proxy = ffi.v8_CreateLegacyPlatformObjectProxy(context, @ptrCast(@alignCast(target.value.handle.ptr)), named_setter) orelse return error.NoProxy;
            defer ffi.v8_Object_Dispose(proxy);
            return ffi.v8_Proxy_GetHandler(proxy) orelse error.NoHandler;
        }
    };
    const collection = try Handler.of(here, "element().children");
    defer ffi.v8_Value_Dispose(collection);
    const collection_again = try Handler.of(here, "element().children");
    defer ffi.v8_Value_Dispose(collection_again);
    const attributes = try Handler.of(here, "element().attributes");
    defer ffi.v8_Value_Dispose(attributes);
    const their_collection = try Handler.of(there, "element().children");
    defer ffi.v8_Value_Dispose(their_collection);
    // The interfaces with a named property setter (Storage: template_registry.hasNamedPropertySetter) need a
    // page; the adapter's function takes any target, and whether its interface has one.
    const with_setter = try Handler.ofNew(here, true);
    defer ffi.v8_Value_Dispose(with_setter);
    const with_setter_again = try Handler.ofNew(here, true);
    defer ffi.v8_Value_Dispose(with_setter_again);
    const without_setter = try Handler.ofNew(here, false);
    defer ffi.v8_Value_Dispose(without_setter);

    try testing.expect(ffi.v8_Value_StrictEquals(collection, collection_again));
    try testing.expect(ffi.v8_Value_StrictEquals(collection, attributes));
    try testing.expect(ffi.v8_Value_StrictEquals(collection, without_setter));
    try testing.expect(ffi.v8_Value_StrictEquals(with_setter, with_setter_again));
    // The "set" trap of an interface with a named property setter is told so: another handler.
    try testing.expect(!ffi.v8_Value_StrictEquals(collection, with_setter));
    // A handler's traps run in the realm that made them: each realm has its own.
    try testing.expect(!ffi.v8_Value_StrictEquals(collection, their_collection));

    // What a debugger that reads [[Handler]] holds: nothing it can change.
    const global = try evalOwned(here, "globalThis");
    defer global.release();
    try protocol.setProperty(here, global.value, "handlerSeen", runtime.JSValue.fromHandle(collection));
    try protocol.setProperty(here, global.value, "setterHandlerSeen", runtime.JSValue.fromHandle(with_setter));
    try expectOk(here,
        \\for (const [name, h] of [["handler", handlerSeen], ["named-setter handler", setterHandlerSeen]]) {
        \\  check(name + " is frozen", Object.isFrozen(h), true);
        \\  check(name + " has no prototype", Object.getPrototypeOf(h), null);
        \\  check(name + " has no get trap", "get" in h, false);
        \\  check(name + " traps", Reflect.ownKeys(h).sort().join(),
        \\        "defineProperty,deleteProperty,getOwnPropertyDescriptor,getPrototypeOf,has,isExtensible,ownKeys,preventExtensions,set,setPrototypeOf");
        \\}
        \\delete globalThis.handlerSeen; delete globalThis.setterHandlerSeen;
        \\failures.join("; ") || "ok"
    );
}

test "a property of Object.prototype named like a proxy trap is no trap of a legacy platform object" {
    // A proxy finds its traps with GetMethod(handler, name), which reads the handler's prototype chain: the
    // handler has none. (It has no own "get" on purpose - v8_wrapper.cpp, "No get trap" - so with
    // %Object.prototype% above it, a page's Object.prototype.get was the [[Get]] trap of every legacy platform
    // object in the realm.)
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    (try evalOwned(realm, setup)).release();
    try expectOk(realm,
        \\const e = element();
        \\let called = 0;
        \\Object.defineProperty(Object.prototype, "get", { value() { called++; return "hijacked"; }, configurable: true, writable: true });
        \\try {
        \\  check("HTMLCollection length", e.children.length, 1);
        \\  check("HTMLCollection[0]", e.children[0], e.firstChild);
        \\  check("HTMLCollection item()", e.children.item(0), e.firstChild);
        \\  check("NamedNodeMap length", e.attributes.length, 1);
        \\  check("NamedNodeMap[0]", e.attributes[0], e.getAttributeNode("data-k"));
        \\  check("NamedNodeMap named getter", e.attributes["data-k"], e.getAttributeNode("data-k"));
        \\} catch (error) {
        \\  failures.push("threw " + error);
        \\} finally {
        \\  delete Object.prototype.get;
        \\}
        \\check("Object.prototype.get called as a trap", called, 0);
        \\failures.join("; ") || "ok"
    );
}

test "every trap answers for its own target through the shared handler, and none is visible to script" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    (try evalOwned(realm, setup)).release();
    try expectOk(realm,
        \\const a = element(), b = element();
        \\b.setAttribute("data-other", "w");
        \\// has / getOwnPropertyDescriptor / ownKeys: each proxy's own target.
        \\check("'data-k' in a.attributes", "data-k" in a.attributes, true);
        \\check("'data-other' in a.attributes", "data-other" in a.attributes, false);
        \\check("'data-other' in b.attributes", "data-other" in b.attributes, true);
        \\check("1 in a.attributes", 1 in a.attributes, false);
        \\check("1 in b.attributes", 1 in b.attributes, true);
        \\check("a.attributes keys", Object.getOwnPropertyNames(a.attributes).join(), "0,data-k");
        \\check("b.attributes keys", Object.getOwnPropertyNames(b.attributes).join(), "0,1,data-k,data-other");
        \\const described = Object.getOwnPropertyDescriptor(b.attributes, "data-other");
        \\check("b.attributes' named property's value", described && described.value, b.getAttributeNode("data-other"));
        \\check("a.attributes has no such property", Object.getOwnPropertyDescriptor(a.attributes, "data-other"), undefined);
        \\check("a.children keys", Object.getOwnPropertyNames(a.children).join(), "0");
        \\// set: an expando of one is not the other's.
        \\a.children.expando = 5;
        \\check("an expando on a.children", a.children.expando, 5);
        \\check("is not on b.children", b.children.expando, undefined);
        \\check("a.children keys with it", Object.getOwnPropertyNames(a.children).join(), "0,expando");
        \\// deleteProperty.
        \\check("delete a.children.expando", delete a.children.expando, true);
        \\check("deleted", "expando" in a.children, false);
        \\// defineProperty.
        \\Object.defineProperty(b.children, "defined", { value: 7, configurable: true });
        \\check("defineProperty on b.children", b.children.defined, 7);
        \\check("is not on a.children", "defined" in a.children, false);
        \\// getPrototypeOf / setPrototypeOf / isExtensible.
        \\check("getPrototypeOf", Object.getPrototypeOf(a.children), HTMLCollection.prototype);
        \\check("isExtensible", Object.isExtensible(a.attributes), true);
        \\const other = Object.create(HTMLCollection.prototype);
        \\check("setPrototypeOf", Reflect.setPrototypeOf(b.children, other), true);
        \\check("changed b.children's prototype", Object.getPrototypeOf(b.children), other);
        \\check("and not a.children's", Object.getPrototypeOf(a.children), HTMLCollection.prototype);
        \\
        \\// No trap is a frame script can see: a setter the "set" trap runs sees only script's functions, in
        \\// its structured stack trace and as its caller.
        \\let frames = null, caller = "unread";
        \\Object.defineProperty(HTMLCollection.prototype, "probe", {
        \\  set: function (v) {
        \\    const old = Error.prepareStackTrace;
        \\    Error.prepareStackTrace = (error, sites) => sites.map(site => site.getFunction());
        \\    try { frames = new Error().stack; } finally { Error.prepareStackTrace = old; }
        \\    caller = arguments.callee.caller;
        \\  },
        \\  configurable: true,
        \\});
        \\function assign() { a.children.probe = 1; }
        \\try { assign(); } finally { delete HTMLCollection.prototype.probe; }
        \\const native = f => typeof f === "function" && /^function [^{]*\{\s*\[native code\]\s*\}$/.test(Function.prototype.toString.call(f));
        \\check("the setter ran", Array.isArray(frames), true);
        \\check("native functions in the stack trace", (frames || []).filter(native).length, 0);
        \\check("the setter's caller is no native function", native(caller), false);
        \\failures.join("; ") || "ok"
    );
}
