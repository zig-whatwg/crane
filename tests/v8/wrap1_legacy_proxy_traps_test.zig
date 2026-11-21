//! A legacy platform object's internal methods never call into the page's script (lane wrap1 b2, the batch's
//! finding 3; the integrator's ruling of 2026-11-13).
//!
//! WebIDL 3.9 gives a legacy platform object its own [[GetOwnProperty]], [[Set]], [[DefineOwnProperty]],
//! [[Delete]], [[PreventExtensions]] and [[OwnPropertyKeys]] - algorithms over the object's supported property
//! indices and names and its own properties - and leaves the rest ordinary. None of them reads a property of the
//! realm's global object or of %Object.prototype%: `"x" in collection` calls no script in any browser.
//!
//! Crane wraps the legacy platform objects with named properties in a Proxy (for [[OwnPropertyKeys]]'s order),
//! and every trap of that proxy called the page's own `Reflect`: looked up on the current realm's global when the
//! trap ran, and cast unchecked (v8_wrapper.cpp ForwardToReflect, LegacyPlatformObjectOwnKeys,
//! LegacyPlatformObjectGetOwnPropertyDescriptor, TrapSet). So:
//! - a page that deleted `Reflect`, or set it to a non-object, ABORTED the process at its next `in`, `delete`,
//!   Object.keys or Object.getOwnPropertyDescriptor on an HTMLCollection, a NamedNodeMap or a Storage (an empty
//!   MaybeLocal into ToLocalChecked);
//! - a page that replaced Reflect.has / ownKeys / getOwnPropertyDescriptor / ... was CALLED for those operations,
//!   with the proxy's target - the object behind it, which no script may hold - as its argument.
//! And the property descriptors the interceptors answer with (of every legacy platform object, proxied or not)
//! were ordinary objects filled by [[Set]]: with `Object.prototype.get` defined V8's ToPropertyDescriptor read it
//! and threw "Invalid property descriptor", and a setter on Object.prototype named "value" was called.
//!
//! Each test tampers with a realm of its own, then asks the same questions of fresh objects as before the
//! tampering: the answers are equal and nothing of the page's was called.

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
        .agent_cluster_cross_origin_isolated = true,
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

/// What every realm of these tests defines before anything is tampered with: the intrinsics the questions use,
/// saved; the objects' makers; and `ask(o)`, the answers of one object to every internal method the traps serve,
/// as one string.
const setup =
    \\globalThis.doc = new Document().implementation.createHTMLDocument("");
    \\globalThis.saved = {
    \\  ownKeys: Reflect.ownKeys, getOwnPropertyDescriptor: Object.getOwnPropertyDescriptor, keys: Object.keys,
    \\  defineProperty: Object.defineProperty, getPrototypeOf: Object.getPrototypeOf, setPrototypeOf: Object.setPrototypeOf,
    \\  isExtensible: Object.isExtensible, preventExtensions: Object.preventExtensions, create: Object.create,
    \\  hasOwn: Object.prototype.hasOwnProperty, stringify: JSON.stringify, String,
    \\};
    \\globalThis.collection = () => {
    \\  const e = doc.createElement("div");
    \\  e.appendChild(doc.createElement("p")).id = "first";
    \\  e.appendChild(doc.createElement("p")).setAttribute("name", "second");
    \\  return e.children;
    \\};
    \\globalThis.attributes = () => {
    \\  const e = doc.createElement("div");
    \\  e.setAttribute("data-k", "v"); e.setAttribute("title", "t");
    \\  return e.attributes;
    \\};
    \\// A descriptor with no prototype: what a page must write once it has put accessors on Object.prototype.
    \\globalThis.descriptor = fields => { const d = saved.create(null); for (const k in fields) d[k] = fields[k]; return d; };
    \\globalThis.attempt = f => { try { return saved.String(f()); } catch (e) { return "threw " + (e && e.name); } };
    \\globalThis.describe = (o, key) => {
    \\  const d = saved.getOwnPropertyDescriptor(o, key);
    \\  if (d === undefined) return "none";
    \\  return (saved.hasOwn.call(d, "value") ? "value:" + typeof d.value : "accessor") + (d.writable ? " w" : "") + (d.enumerable ? " e" : "") + (d.configurable ? " c" : "");
    \\};
    \\globalThis.ask = (o, name) => {
    \\  const a = [];
    \\  a.push("has 0: " + attempt(() => 0 in o));
    \\  a.push("has 5: " + attempt(() => 5 in o));
    \\  a.push("has " + name + ": " + attempt(() => name in o));
    \\  a.push("has nope: " + attempt(() => "nope" in o));
    \\  a.push("has item: " + attempt(() => "item" in o));
    \\  a.push("keys: " + attempt(() => saved.keys(o).join()));
    \\  a.push("ownKeys: " + attempt(() => saved.ownKeys(o).join()));
    \\  a.push("descriptor 0: " + attempt(() => describe(o, "0")));
    \\  a.push("descriptor 5: " + attempt(() => describe(o, "5")));
    \\  a.push("descriptor " + name + ": " + attempt(() => describe(o, name)));
    \\  a.push("descriptor nope: " + attempt(() => describe(o, "nope")));
    \\  a.push("hasOwn 0: " + attempt(() => saved.hasOwn.call(o, "0")));
    \\  a.push("hasOwn " + name + ": " + attempt(() => saved.hasOwn.call(o, name)));
    \\  a.push("define expando: " + attempt(() => (saved.defineProperty(o, "defined", descriptor({ value: 7, configurable: true, enumerable: true, writable: true })), o.defined)));
    \\  a.push("define over " + name + ": " + attempt(() => saved.defineProperty(o, name, descriptor({ value: 1, configurable: true })) === o));
    \\  a.push("define over 0: " + attempt(() => saved.defineProperty(o, "0", descriptor({ value: 1, configurable: true })) === o));
    \\  a.push("set expando: " + attempt(() => (o.expando = 5, o.expando)));
    \\  a.push("keys with both: " + attempt(() => saved.ownKeys(o).join()));
    \\  a.push("delete expando: " + attempt(() => delete o.expando));
    \\  a.push("delete defined: " + attempt(() => delete o.defined));
    \\  a.push("delete 0: " + attempt(() => delete o[0]));
    \\  a.push("delete 5: " + attempt(() => delete o[5]));
    \\  a.push("delete " + name + ": " + attempt(() => delete o[name]));
    \\  a.push("strict delete 0: " + attempt(() => { "use strict"; return delete o[0]; }));
    \\  const heir = saved.create(o);
    \\  a.push("set through an heir: " + attempt(() => (heir.fresh = 1, saved.hasOwn.call(heir, "fresh") + " " + ("fresh" in o))));
    \\  a.push("set 0 through an heir: " + attempt(() => (heir[0] = 1, saved.hasOwn.call(heir, "0"))));
    \\  a.push("prototype: " + attempt(() => saved.getPrototypeOf(o) === saved.getPrototypeOf(saved.getPrototypeOf(heir))));
    \\  a.push("extensible: " + attempt(() => saved.isExtensible(o)));
    \\  a.push("preventExtensions: " + attempt(() => saved.preventExtensions(o) === o));
    \\  a.push("still extensible: " + attempt(() => saved.isExtensible(o)));
    \\  const other = saved.create(saved.getPrototypeOf(o));
    \\  a.push("setPrototypeOf: " + attempt(() => saved.setPrototypeOf(o, other) === o && saved.getPrototypeOf(o) === other));
    \\  return a.join(" | ");
    \\};
    \\globalThis.answers = () => "collection { " + ask(collection(), "first") + " } attributes { " + ask(attributes(), "data-k") + " }";
    \\"made"
;

/// Replace every function of `Reflect` and count the calls.
const replace_reflect =
    \\globalThis.calls = [];
    \\for (const name of saved.ownKeys(Reflect)) {
    \\  if (typeof Reflect[name] !== "function") continue;
    \\  Reflect[name] = function (...args) { calls.push(name); throw new Error("the page's Reflect." + name + " was called"); };
    \\}
    \\"replaced"
;

const Realm = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Realm {
        test_process.start();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try windowRealm(agent);
        (try evalOwned(realm, setup)).release();
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Realm) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    /// `answers()` of the realm, OWNED (testing.allocator).
    fn answers(self: Realm) ![]u8 {
        return answersOf(self.realm, "answers()");
    }
};

fn answersOf(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    errdefer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

/// The realm answers as it did before `tamper` ran, and `tamper`'s `calls`, if it counts any, stays empty.
fn expectUnchangedBy(tamper: []const u8) !void {
    const page = try Realm.open();
    defer page.close();
    const before = try page.answers();
    defer testing.allocator.free(before);
    // The questions have answers at all: a collection's supported index and name, an attribute map's.
    try testing.expect(std.mem.indexOf(u8, before, "has 0: true") != null);
    try testing.expect(std.mem.indexOf(u8, before, "has first: true") != null);
    try testing.expect(std.mem.indexOf(u8, before, "has data-k: true") != null);
    try testing.expect(std.mem.indexOf(u8, before, "threw") == null or std.mem.indexOf(u8, before, "threw TypeError") != null);

    (try evalOwned(page.realm, tamper)).release();
    const after = try page.answers();
    defer testing.allocator.free(after);
    if (!std.mem.eql(u8, before, after)) std.debug.print("before: {s}\nafter:  {s}\n", .{ before, after });
    try testing.expectEqualStrings(before, after);
    try expectOk(page.realm, "typeof calls === 'undefined' || calls.length === 0 ? 'ok' : 'the page was called: ' + calls.join()");
}

test "the internal methods' answers are WebIDL's: indices, names, own properties, and no prevented extensions" {
    // The steps the proxy's traps and the target's interceptors implement together (WebIDL 3.9.1-3.9.6), on an
    // HTMLCollection of two elements (one with an id) and a NamedNodeMap of two attributes.
    const page = try Realm.open();
    defer page.close();
    try expectOk(page.realm,
        \\const failures = [];
        \\const check = (name, got, want) => { if (got !== want) failures.push(name + ": " + saved.String(got)); };
        \\const c = collection(), m = attributes();
        \\// 3.9.6 [[OwnPropertyKeys]]: supported indices, then supported names, then own string keys, then symbols.
        \\check("collection keys", saved.ownKeys(c).join(), "0,1,first,second");
        \\check("attribute map keys", saved.ownKeys(m).join(), "0,1,data-k,title");
        \\c.expando = 1; const symbol = Symbol("s"); c[symbol] = 2;
        \\check("collection keys with own properties", saved.ownKeys(c).map(saved.String).join(), "0,1,first,second,expando,Symbol(s)");
        \\// 3.9.1 [[GetOwnProperty]]: an index's and a name's descriptor ([LegacyUnenumerableNamedProperties]).
        \\check("collection[0]'s descriptor", describe(c, "0"), "value:object e c");
        \\check("collection.first's descriptor", describe(c, "first"), "value:object c");
        \\check("an unsupported index has none", describe(c, "5"), "none");
        \\// 3.9.4 [[Delete]]: a supported index or name is not deleted; an unsupported index and an own property are.
        \\check("delete collection[0]", delete c[0], false);
        \\check("delete collection[5]", delete c[5], true);
        \\check("delete collection.first", delete c.first, false);
        \\check("delete collection.expando", delete c.expando, true);
        \\// 3.9.3 [[DefineOwnProperty]]: no indexed or named setter, so an index or a supported name is refused.
        \\check("define collection[0]", attempt(() => saved.defineProperty(c, "0", { value: 1 })), "threw TypeError");
        \\check("define collection[5]", attempt(() => saved.defineProperty(c, "5", { value: 1 })), "threw TypeError");
        \\check("define collection.first", attempt(() => saved.defineProperty(c, "first", { value: 1 })), "threw TypeError");
        \\// 3.9.2 [[Set]] with another Receiver - an object whose prototype is the collection. Step 2's ownDesc
        \\// ignores named properties (LegacyPlatformObjectGetOwnProperty(O, P, true)), so a supported name is
        \\// no property of O here and the value becomes the Receiver's own (step 3, ES OrdinarySetWithOwnDescriptor
        \\// 2.e); a supported index is O's read-only data property (no indexed setter): refused.
        \\const heir = saved.create(collection());
        \\heir.first = "x";
        \\check("an heir's assignment over a supported name is the heir's own property", saved.hasOwn.call(heir, "first") && heir.first, "x");
        \\check("and the collection's named property is untouched", typeof saved.getPrototypeOf(heir).first, "object");
        \\heir[0] = "y";
        \\check("an heir's assignment over a supported index is refused", saved.hasOwn.call(heir, "0"), false);
        \\check("in strict code it throws", attempt(() => { "use strict"; heir[0] = "y"; }), "threw TypeError");
        \\heir[5] = "z";
        \\check("an heir's assignment to an unsupported index is the heir's own property", saved.hasOwn.call(heir, "5") && heir[5], "z");
        \\// ES OrdinarySetWithOwnDescriptor steps 2.b-d, on the Receiver.
        \\const c2 = collection();
        \\check("a Receiver that is no object", Reflect.set(c2, "first", 1, 5), false);
        \\check("a Receiver with a read-only own property", Reflect.set(c2, "first", 1, Object.freeze({ first: 0 })), false);
        \\check("a Receiver with an own accessor", Reflect.set(c2, "first", 1, { get first() { return 0; }, set first(v) {} }), false);
        \\const writable = { first: 0 };
        \\check("a Receiver with a writable own property", Reflect.set(c2, "first", 9, writable) && writable.first, 9);
        \\const hidden = {}; saved.defineProperty(hidden, "first", { value: 0, writable: true, enumerable: false, configurable: true });
        \\check("keeps that property's attributes", Reflect.set(c2, "first", 9, hidden) && describe(hidden, "first"), "value:number w c");
        \\// 3.9.5 [[PreventExtensions]]: step 1, return false.
        \\check("Object.preventExtensions(collection)", attempt(() => saved.preventExtensions(c)), "threw TypeError");
        \\check("Reflect.preventExtensions(collection)", Reflect.preventExtensions(c), false);
        \\check("the collection stays extensible", saved.isExtensible(c), true);
        \\check("Object.preventExtensions(attribute map)", attempt(() => saved.preventExtensions(m)), "threw TypeError");
        \\check("Object.freeze(collection)", attempt(() => Object.freeze(c)), "threw TypeError");
        \\failures.join("; ") || "ok"
    );
}

test "a page that deletes Reflect changes no answer of a legacy platform object" {
    try expectUnchangedBy("delete globalThis.Reflect ? 'deleted' : 'kept'");
}

test "a page that sets Reflect to a non-object changes no answer of a legacy platform object" {
    try expectUnchangedBy("globalThis.Reflect = 5; 'set'");
}

test "a page that empties Reflect changes no answer of a legacy platform object" {
    try expectUnchangedBy("for (const name of saved.ownKeys(Reflect)) delete Reflect[name]; 'emptied'");
}

test "a page that replaces Reflect's functions is not called by a legacy platform object's internal methods" {
    try expectUnchangedBy(replace_reflect);
}

test "a page that replaces Reflect's functions with non-functions changes no answer of a legacy platform object" {
    try expectUnchangedBy("for (const name of saved.ownKeys(Reflect)) Reflect[name] = 1; 'numbers'");
}

test "accessors a page puts on Object.prototype are not called for a legacy platform object's property descriptors" {
    // A descriptor the binding hands V8 for an indexed or a named property (WebIDL 3.9.7
    // LegacyPlatformObjectGetOwnProperty's Property Descriptor) is a record, not an object of the page's:
    // nothing of %Object.prototype% is in it. Asked of the proxied collections and of a NodeList and a
    // DOMTokenList, whose interceptors answer V8 directly.
    const page = try Realm.open();
    defer page.close();
    (try evalOwned(page.realm,
        \\globalThis.list = () => { const e = doc.createElement("div"); e.appendChild(doc.createElement("p")); return e.querySelectorAll("p"); };
        \\globalThis.tokens = () => { const e = doc.createElement("div"); e.className = "a b"; return e.classList; };
        \\globalThis.answers = () => "collection { " + ask(collection(), "first") + " } attributes { " + ask(attributes(), "data-k") + " } " +
        \\  "list { " + describe(list(), "0") + " | " + saved.keys(list()).join() + " | " + (0 in list()) + " } " +
        \\  "tokens { " + describe(tokens(), "1") + " | " + saved.keys(tokens()).join() + " | " + saved.hasOwn.call(tokens(), "0") + " }";
        \\"made"
    )).release();
    const before = try page.answers();
    defer testing.allocator.free(before);
    try testing.expect(std.mem.indexOf(u8, before, "list { value:object e c | 0 | true }") != null);
    try testing.expect(std.mem.indexOf(u8, before, "tokens { value:string e c | 0,1 | true }") != null);

    (try evalOwned(page.realm,
        \\globalThis.calls = [];
        \\for (const name of ["get", "set", "value", "writable", "enumerable", "configurable"]) {
        \\  saved.defineProperty(Object.prototype, name, descriptor({
        \\    get() { calls.push("get " + name); return undefined; },
        \\    set(v) { calls.push("set " + name); },
        \\    configurable: true,
        \\  }));
        \\}
        \\"polluted"
    )).release();
    const after = try page.answers();
    defer testing.allocator.free(after);
    if (!std.mem.eql(u8, before, after)) std.debug.print("before: {s}\nafter:  {s}\n", .{ before, after });
    try testing.expectEqualStrings(before, after);
    try expectOk(page.realm, "calls.length === 0 ? 'ok' : 'the page was called: ' + calls.join()");
}

test "another realm's Reflect is not asked either: a collection answers the same from a realm that replaced its own, and after its own realm's is replaced" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const here = try windowRealm(agent);
    defer protocol.destroyWindowRealm(here, .global_detached);
    const there = try windowRealm(agent);
    defer protocol.destroyWindowRealm(there, .global_detached);
    (try evalOwned(here, setup)).release();
    (try evalOwned(there, setup)).release();
    {
        // Their makers, called from this realm: the collections are their realm's.
        const theirs = try evalOwned(there, "({ collection, attributes })");
        defer theirs.release();
        const global = try evalOwned(here, "globalThis");
        defer global.release();
        try protocol.setProperty(here, global.value, "theirs", theirs.value);
    }
    const question = "'collection { ' + ask(theirs.collection(), 'first') + ' } attributes { ' + ask(theirs.attributes(), 'data-k') + ' }'";
    const before = try answersOf(here, question);
    defer testing.allocator.free(before);
    try testing.expect(std.mem.indexOf(u8, before, "has first: true") != null);

    // This realm's Reflect replaced: the traps are their realm's functions.
    (try evalOwned(here, replace_reflect)).release();
    const with_ours_replaced = try answersOf(here, question);
    defer testing.allocator.free(with_ours_replaced);
    try testing.expectEqualStrings(before, with_ours_replaced);
    try expectOk(here, "calls.length === 0 ? 'ok' : 'this realm was called: ' + calls.join()");

    // Their realm's Reflect replaced, and then deleted.
    (try evalOwned(there, replace_reflect)).release();
    const with_theirs_replaced = try answersOf(here, question);
    defer testing.allocator.free(with_theirs_replaced);
    try testing.expectEqualStrings(before, with_theirs_replaced);
    try expectOk(there, "calls.length === 0 ? 'ok' : 'their realm was called: ' + calls.join()");
    (try evalOwned(there, "delete globalThis.Reflect ? 'deleted' : 'kept'")).release();
    const with_theirs_deleted = try answersOf(here, question);
    defer testing.allocator.free(with_theirs_deleted);
    try testing.expectEqualStrings(before, with_theirs_deleted);
}

test "the proxy of an interface with a named property setter asks no Reflect either" {
    // Storage is the one proxied interface with a named property setter, and needs a page; the adapter's
    // function makes the same proxy around any target (wrap1_legacy_proxy_handler_test.zig does the same).
    const page = try Realm.open();
    defer page.close();
    const context: *ffi.Context = @ptrCast(@alignCast(page.realm.engine_ctx orelse return error.NoContext));
    const global = try evalOwned(page.realm, "globalThis");
    defer global.release();
    for ([_][]const u8{ "plain", "tampered" }) |name| {
        const target = try evalOwned(page.realm, "({ own: 1 })");
        defer target.release();
        const proxy = ffi.v8_CreateLegacyPlatformObjectProxy(context, @ptrCast(@alignCast(target.value.handle.ptr)), true) orelse return error.NoProxy;
        defer ffi.v8_Object_Dispose(proxy);
        try protocol.setProperty(page.realm, global.value, name, runtime.JSValue.fromHandle(proxy));
    }
    const question =
        \\((o) => [
        \\  attempt(() => "own" in o), attempt(() => "nope" in o), attempt(() => saved.keys(o).join()),
        \\  attempt(() => describe(o, "own")), attempt(() => (o.named = 3, o.named)), attempt(() => saved.ownKeys(o).join()),
        \\  attempt(() => delete o.named), attempt(() => (saved.defineProperty(o, "defined", descriptor({ value: 7, configurable: true })), o.defined)),
        \\  attempt(() => { const heir = saved.create(o); heir.fresh = 1; return saved.hasOwn.call(heir, "fresh") + " " + ("fresh" in o); }),
        \\  attempt(() => saved.getPrototypeOf(o) === Object.prototype), attempt(() => saved.isExtensible(o)),
        \\  attempt(() => saved.preventExtensions(o) === o),
        \\].join(" | "))
    ;
    var source: [1400]u8 = undefined;
    const before = try answersOf(page.realm, try std.fmt.bufPrint(&source, "{s}(plain)", .{question}));
    defer testing.allocator.free(before);
    try testing.expect(std.mem.startsWith(u8, before, "true | false | own | value:number w e c | 3 | own,named | true | 7 | true false | true | true | "));

    (try evalOwned(page.realm, replace_reflect)).release();
    const after = try answersOf(page.realm, try std.fmt.bufPrint(&source, "{s}(tampered)", .{question}));
    defer testing.allocator.free(after);
    if (!std.mem.eql(u8, before, after)) std.debug.print("before: {s}\nafter:  {s}\n", .{ before, after });
    try testing.expectEqualStrings(before, after);
    try expectOk(page.realm, "calls.length === 0 ? 'ok' : 'the page was called: ' + calls.join()");
}

test "[[Set]] on a legacy platform object reaches a Proxy on its prototype chain through that Proxy's own [[Set]], once" {
    // WebIDL 3.9.2 [[Set]] step 3 is OrdinarySetWithOwnDescriptor(O, P, V, Receiver, ownDesc), and with no
    // ownDesc that is ES 10.1.9.2 step 1: "Let parent be ? O.[[GetPrototypeOf]](). If parent is not null,
    // return ? parent.[[Set]](P, V, Receiver)" - the PARENT's internal method, whatever the parent is. The
    // trap used to walk the chain itself, reading each object's own property descriptor and prototype through
    // V8's API: an ordinary parent cannot tell, but a Proxy a page put on the chain was asked for
    // getOwnPropertyDescriptor and getPrototypeOf, and its `set` trap - the one a browser calls - never ran.
    // The Proxy is made the collection's own prototype (Object.setPrototypeOf on the collection, which WebIDL
    // allows: only a [Global] interface's objects have an immutable prototype).
    // (Lane wrap1 b3. In a browser a legacy platform object is no Proxy: its [[Set]] is the engine's own
    // ordinary set with the interceptors, which reaches a Proxy on the chain through JSProxy's [[Set]].)
    const page = try Realm.open();
    defer page.close();
    try expectOk(page.realm,
        \\const failures = [];
        \\const check = (name, got, want) => { if (got !== want) failures.push(name + ": " + saved.String(got)); };
        \\const log = [];
        \\const subject = collection();
        \\const heir = saved.create(subject);
        \\// The Proxy goes between the collection and its interface prototype object (whose own prototype
        \\// Crane makes immutable): its target inherits from that prototype, so members still resolve.
        \\const interfacePrototype = saved.getPrototypeOf(subject);
        \\const backing = saved.create(interfacePrototype);
        \\saved.defineProperty(backing, "viaSetter", descriptor({ set(v) { log.push("setter " + v + " on " + (this === subject ? "the collection" : "another object")); }, configurable: true }));
        \\saved.defineProperty(backing, "frozen", descriptor({ value: 1, writable: false, configurable: true }));
        \\const set = Reflect.set, gopd = Reflect.getOwnPropertyDescriptor, gpo = Reflect.getPrototypeOf, define = Reflect.defineProperty, has = Reflect.has, get = Reflect.get;
        \\const onChain = new Proxy(backing, {
        \\  set(t, k, v, r) { log.push("set " + saved.String(k) + " receiver " + (r === subject ? "the collection" : r === heir ? "the heir" : "other")); return set(t, k, v, r); },
        \\  getOwnPropertyDescriptor(t, k) { log.push("getOwnPropertyDescriptor " + saved.String(k)); return gopd(t, k); },
        \\  getPrototypeOf(t) { log.push("getPrototypeOf"); return gpo(t); },
        \\  defineProperty(t, k, d) { log.push("defineProperty " + saved.String(k)); return define(t, k, d); },
        \\  has(t, k) { log.push("has " + saved.String(k)); return has(t, k); },
        \\  get(t, k, r) { return get(t, k, r); },
        \\});
        \\saved.setPrototypeOf(subject, onChain);
        \\try {
        \\  // A new name: the Proxy's [[Set]] runs once, finds nothing, and the value becomes the collection's own.
        \\  log.length = 0;
        \\  subject.fresh = 5;
        \\  check("a new name: the traps called", log.join(" | "), "set fresh receiver the collection");
        \\  check("a new name: the collection's own property", saved.hasOwn.call(subject, "fresh") && subject.fresh, 5);
        \\  check("a new name: nothing on the Proxy's target", saved.hasOwn.call(backing, "fresh"), false);
        \\  // A setter behind the Proxy runs with the collection as its receiver.
        \\  log.length = 0;
        \\  subject.viaSetter = 7;
        \\  check("a setter behind the Proxy", log.join(" | "), "set viaSetter receiver the collection | setter 7 on the collection");
        \\  // A read-only data property behind the Proxy refuses: quietly in sloppy code, a TypeError in strict.
        \\  log.length = 0;
        \\  subject.frozen = 2;
        \\  check("a read-only property behind the Proxy: the traps called", log.join(" | "), "set frozen receiver the collection");
        \\  check("a read-only property behind the Proxy: nothing made", saved.hasOwn.call(subject, "frozen"), false);
        \\  check("a read-only property behind the Proxy, strict", attempt(() => { "use strict"; subject.frozen = 2; }), "threw TypeError");
        \\  // Through an heir of the collection (another Receiver): the same one call.
        \\  log.length = 0;
        \\  heir.inherited = 9;
        \\  check("through an heir: the traps called", log.join(" | "), "set inherited receiver the heir");
        \\  check("through an heir: the heir's own property", saved.hasOwn.call(heir, "inherited") && heir.inherited, 9);
        \\  check("through an heir: not the collection's", saved.hasOwn.call(subject, "inherited"), false);
        \\  // A symbol goes the same way.
        \\  log.length = 0;
        \\  const mark = Symbol("mark");
        \\  subject[mark] = 1;
        \\  check("a symbol: the traps called", log.join(" | "), "set Symbol(mark) receiver the collection");
        \\  check("a symbol: the collection's own property", subject[mark], 1);
        \\  // A Receiver that is no Object (Reflect.set's fourth argument) reaches the trap as it is.
        \\  log.length = 0;
        \\  check("a primitive Receiver: the answer", set(subject, "viaPrimitive", 1, 5), false);
        \\  check("a primitive Receiver: the traps called", log.join(" | "), "set viaPrimitive receiver other");
        \\} finally {
        \\  saved.setPrototypeOf(subject, interfacePrototype);
        \\}
        \\failures.join("; ") || "ok"
    );
}

test "a Proxy on a legacy platform object's prototype chain has its [[Set]] performed whole: no trap, a false, a revoked proxy, the invariants" {
    // ES 10.5.9, the steps a Proxy's [[Set]] has besides calling its trap (specs/ecma/
    // ordinary-and-exotic-objects-behaviours.md): a revoked proxy throws (step 1); with no `set` trap the call
    // goes to the Proxy's TARGET's [[Set]] with the same Receiver (step 6), which asks none of the handler's
    // other traps; a trap's false is the store's false, a TypeError in strict code (step 8); and a trap that
    // answers true for a property its target holds as non-configurable and read-only with another value, or as
    // a non-configurable accessor with no setter, throws (step 10). V8's API has no [[Set]] that takes a
    // Receiver and answers, so the adapter performs these steps itself (v8_wrapper.cpp TrapSet).
    const page = try Realm.open();
    defer page.close();
    try expectOk(page.realm,
        \\const failures = [];
        \\const check = (name, got, want) => { if (got !== want) failures.push(name + ": " + saved.String(got)); };
        \\const log = [];
        \\const subject = collection();
        \\const interfacePrototype = saved.getPrototypeOf(subject);
        \\const set = Reflect.set, gopd = Reflect.getOwnPropertyDescriptor, gpo = Reflect.getPrototypeOf;
        \\const through = (backing, handler) => { const p = new Proxy(backing, handler); saved.setPrototypeOf(subject, p); return p; };
        \\try {
        \\  // No `set` trap: the target's [[Set]], which reads the target and never the handler's other traps.
        \\  let backing = saved.create(interfacePrototype);
        \\  let seen = "not called";
        \\  saved.defineProperty(backing, "viaSetter", descriptor({ set(v) { seen = v + (this === subject ? " on the collection" : " elsewhere"); }, configurable: true }));
        \\  through(backing, {
        \\    getOwnPropertyDescriptor(t, k) { log.push("getOwnPropertyDescriptor " + saved.String(k)); return gopd(t, k); },
        \\    getPrototypeOf(t) { log.push("getPrototypeOf"); return gpo(t); },
        \\  });
        \\  subject.viaSetter = 4;
        \\  subject.plain = 6;
        \\  check("no set trap: the target's setter", seen, "4 on the collection");
        \\  check("no set trap: the collection's own property", saved.hasOwn.call(subject, "plain") && subject.plain, 6);
        \\  check("no set trap: no other trap called", log.join(" | "), "");
        \\  // A trap's false: nothing stored, quietly in sloppy code and a TypeError in strict.
        \\  through(saved.create(interfacePrototype), { set() { return false; } });
        \\  subject.refused = 1;
        \\  check("a trap's false: nothing made", saved.hasOwn.call(subject, "refused"), false);
        \\  check("a trap's false, strict", attempt(() => { "use strict"; subject.refused = 1; }), "threw TypeError");
        \\  // A trap's true with nothing done: the store answers true and makes nothing.
        \\  through(saved.create(interfacePrototype), { set() { return 1; } });
        \\  check("a trap's true, strict", attempt(() => { "use strict"; subject.swallowed = 1; return "no error"; }), "no error");
        \\  check("a trap's true: nothing made", saved.hasOwn.call(subject, "swallowed"), false);
        \\  // A `set` that is not callable.
        \\  through(saved.create(interfacePrototype), { set: 1 });
        \\  check("a set that is no function", attempt(() => { subject.x1 = 1; }), "threw TypeError");
        \\  // The invariants: a true the target contradicts.
        \\  backing = saved.create(interfacePrototype);
        \\  saved.defineProperty(backing, "locked", descriptor({ value: 1, writable: false, configurable: false }));
        \\  saved.defineProperty(backing, "getterOnly", descriptor({ get() { return 1; }, configurable: false }));
        \\  through(backing, { set() { return true; } });
        \\  check("a true over a locked value, another value", attempt(() => { subject.locked = 2; }), "threw TypeError");
        \\  check("a true over a locked value, the same value", attempt(() => { subject.locked = 1; return "no error"; }), "no error");
        \\  check("a true over a locked accessor with no setter", attempt(() => { subject.getterOnly = 2; }), "threw TypeError");
        \\  // A revoked proxy.
        \\  const revocable = Proxy.revocable(saved.create(interfacePrototype), {});
        \\  saved.setPrototypeOf(subject, revocable.proxy);
        \\  revocable.revoke();
        \\  check("a revoked proxy", attempt(() => { subject.x2 = 1; }), "threw TypeError");
        \\} finally {
        \\  saved.setPrototypeOf(subject, interfacePrototype);
        \\}
        \\failures.join("; ") || "ok"
    );
}

test "[[Set]] over a legacy platform object's own property keeps the property's attributes, and refuses a read-only one" {
    // OrdinarySetWithOwnDescriptor with an ownDesc (ES 10.1.9.2 step 2): a data property that is not writable
    // returns false (2.a), and a writable one is updated with the descriptor { [[Value]]: V } alone (2.d.iii-iv)
    // - its other attributes stay. The trap used to redefine the property whole: writable, enumerable and
    // configurable, whatever it had been.
    const page = try Realm.open();
    defer page.close();
    try expectOk(page.realm,
        \\const failures = [];
        \\const check = (name, got, want) => { if (got !== want) failures.push(name + ": " + saved.String(got)); };
        \\const subject = collection();
        \\saved.defineProperty(subject, "hidden", descriptor({ value: 1, writable: true, enumerable: false, configurable: false }));
        \\subject.hidden = 2;
        \\check("a writable, non-enumerable own property: its value", subject.hidden, 2);
        \\check("a writable, non-enumerable own property: its attributes", describe(subject, "hidden"), "value:number w");
        \\saved.defineProperty(subject, "fixed", descriptor({ value: 1, writable: false, enumerable: true, configurable: true }));
        \\subject.fixed = 2;
        \\check("a read-only own property keeps its value", subject.fixed, 1);
        \\check("a read-only own property keeps its attributes", describe(subject, "fixed"), "value:number e c");
        \\check("a read-only own property, strict", attempt(() => { "use strict"; subject.fixed = 2; }), "threw TypeError");
        \\let seen = "not called";
        \\saved.defineProperty(subject, "own", descriptor({ set(v) { seen = v + (this === subject ? " on the collection" : " elsewhere"); }, configurable: true }));
        \\subject.own = 3;
        \\check("an own setter runs", seen, "3 on the collection");
        \\saved.defineProperty(subject, "getterOnly", descriptor({ get() { return 1; }, configurable: true }));
        \\check("an own accessor with no setter, strict", attempt(() => { "use strict"; subject.getterOnly = 2; }), "threw TypeError");
        \\failures.join("; ") || "ok"
    );
}
