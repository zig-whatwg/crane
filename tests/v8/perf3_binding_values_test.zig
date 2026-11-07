//! What the binding hands script, and takes from it, is the same whichever
//! path a value converts on.
//!
//! perf3's phase 1 (tmp/plans/perf3-design.md section 5) makes the getter,
//! setter and operation callbacks read a String, Number, Boolean or wrapper
//! argument straight from the call's arguments, set results straight into the
//! return slot, read `this` from its internal fields and make a context only
//! when a slow path asks. Every other value keeps the conversion it has today
//! (an object's ToString, a Symbol's TypeError, a [LegacyNullToEmptyString]
//! null). These cases pin both: each kind once with a value the fast path
//! takes and once with one it hands on, with the same expected answer, and the
//! handle balance of each statement over 64 calls (V8's own live count, as
//! per_call_handle_test.zig reads it). They hold on main as they must after:
//! a characterization of WebIDL 3.2's conversions, not of the paths.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

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

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    /// Runs `body` as a function body over `doc` (an HTML document - the
    /// realm has none of its own) and `e` (a div of it); it returns "ok" or
    /// says what it found instead.
    fn expectOk(self: Page, comptime body: []const u8) !void {
        const source =
            \\(() => {
            \\  const doc = globalThis.perf3Doc ||= new Document().implementation.createHTMLDocument("");
            \\  const e = doc.createElement("div");
            \\
        ++ body ++
            \\
            \\  return "ok";
            \\})()
        ;
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported)\n", .{ @errorName(err), reports.count });
            return err;
        };
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        if (!std.mem.eql(u8, got, "ok")) {
            std.debug.print("{s}\n", .{got});
            return error.WrongAnswer;
        }
    }

    /// The global handle bytes 64 runs of `statement` leave once a first
    /// round has made what later ones reuse (per_call_handle_test.zig).
    fn expectNoHandleLeftBy(self: Page, comptime statement: []const u8) !void {
        const loop =
            \\(() => {
            \\  const doc = globalThis.perf3Doc ||= new Document().implementation.createHTMLDocument("");
            \\  const e = globalThis.perf3Probe ||= doc.createElement("div");
            \\  for (let k = 0; k < 64; k++) {
            \\    try {
        ++ statement ++
            \\;
            \\    } catch (err) {}
            \\  }
            \\  return "ok";
            \\})()
        ;
        var reports: Reports = .{};
        const first = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = loop }, "", null, testing.allocator, reports.reporter());
        testing.allocator.free(first);
        try self.collect();
        const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        const second = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = loop }, "", null, testing.allocator, reports.reporter());
        testing.allocator.free(second);
        try self.collect();
        const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        try testing.expectEqual(@as(usize, 0), reports.count);
        if (after - before > 0) {
            std.debug.print("{s}: {d} global handle bytes left over 64 calls\n", .{ statement, after - before });
            return error.HandleLeftPerCall;
        }
    }
};

test "a string result reads back the code units it was given: ASCII, Latin-1, BMP, astral, lone surrogates, empty" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  for (const v of ["ascii", "café", "日本", "\u{1F600}", "a\uD800b", "\uDC00", "", "x".repeat(300)]) {
        \\    e.id = v;
        \\    if (e.id !== v) return "id " + JSON.stringify(v) + " read " + JSON.stringify(e.id);
        \\    e.setAttribute("title", v);
        \\    if (e.getAttribute("title") !== v) return "getAttribute " + JSON.stringify(v);
        \\  }
    );
}

test "null, enumeration, wrapper, number and boolean results" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  if (e.getAttribute("missing") !== null) return "a missing attribute is not null";
        \\  if (new Response().type !== "default") return "enumeration result " + new Response().type;
        \\  const c = doc.createElement("span");
        \\  e.appendChild(c);
        \\  if (c.parentNode !== e || e.firstChild !== c) return "wrapper identity";
        \\  if (e.compareDocumentPosition(c) !== 20) return "number result " + e.compareDocumentPosition(c);
        \\  e.setAttribute("x", "");
        \\  if (e.hasAttribute("x") !== true || e.hasAttribute("y") !== false) return "boolean result";
        \\  const v = doc.createElement("video");
        \\  if (v.canPlayType("bogus/type") !== "") return "an enumeration result of an operation " + JSON.stringify(v.canPlayType("bogus/type"));
    );
}

test "a result kept past its call - in a variable, through a collection - reads back what it was" {
    const page = try Page.open();
    defer page.close();
    // A string the getter set straight into the return slot is a value of
    // script's like any other: nothing of it belongs to the call.
    try page.expectOk(
        \\  globalThis.perf3Kept = [];
        \\  for (let i = 0; i < 200; i++) {
        \\    e.id = "kept-" + i + (i & 1 ? "\u00e9" : "") + (i & 2 ? "\uD800" : "");
        \\    e.setAttribute("data-k", "attr-" + i);
        \\    perf3Kept.push(e.id, e.getAttribute("data-k"), e.getAttribute("missing"), e.hasAttribute("data-k"), e.compareDocumentPosition(e));
        \\  }
    );
    try page.collect();
    try page.expectOk(
        \\  for (let i = 0; i < 200; i++) {
        \\    const id = "kept-" + i + (i & 1 ? "\u00e9" : "") + (i & 2 ? "\uD800" : "");
        \\    const at = 5 * i;
        \\    if (perf3Kept[at] !== id) return "kept id " + i + ": " + JSON.stringify(perf3Kept[at]);
        \\    if (perf3Kept[at + 1] !== "attr-" + i) return "kept attribute " + i;
        \\    if (perf3Kept[at + 2] !== null || perf3Kept[at + 3] !== true || perf3Kept[at + 4] !== 0) return "kept null/boolean/number " + i;
        \\  }
    );
}

test "a DOMString argument: a String as it is, anything else through ToString" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  let calls = 0;
        \\  e.setAttribute("data-a", { toString() { calls++; return "x"; } });
        \\  if (calls !== 1 || e.getAttribute("data-a") !== "x") return "toString ran " + calls + " times";
        \\  e.id = 7;
        \\  if (e.id !== "7") return "a number converts to " + e.id;
        \\  e.id = true;
        \\  if (e.id !== "true") return "a boolean converts to " + e.id;
        \\  e.id = undefined;
        \\  if (e.id !== "undefined") return "undefined converts to " + e.id;
        \\  try { e.id = Symbol("s"); return "a Symbol converted"; } catch (err) { if (!(err instanceof TypeError)) return "a Symbol threw " + err; }
        \\  const boom = new Error("boom");
        \\  try { e.setAttribute("data-b", { toString() { throw boom; } }); return "a throwing toString did not throw"; } catch (err) { if (err !== boom) return "another object was thrown: " + err; }
        \\  e.innerHTML = "<i></i>";
        \\  e.innerHTML = null;
        \\  if (e.innerHTML !== "") return "[LegacyNullToEmptyString] gave " + JSON.stringify(e.innerHTML);
        \\  const huge = "z".repeat(1 << 20) + "é";
        \\  e.setAttribute("data-h", huge);
        \\  if (e.getAttribute("data-h") !== huge) return "a 1 MiB argument";
    );
}

test "USVString and ByteString arguments" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const p = new URLSearchParams();
        \\  p.append("a\uD800", "b");
        \\  if (p.toString() !== "a%EF%BF%BD=b") return "a lone surrogate in a USVString gave " + p.toString();
        \\  const h = new Headers();
        \\  h.append("a", "ÿ");
        \\  try { h.append("b", "Ā"); return "a code unit above 0xFF in a ByteString converted"; } catch (err) { if (!(err instanceof TypeError)) return "ByteString threw " + err; }
    );
}

test "boolean, number, restricted double and enumeration arguments" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  e.hidden = 1;
        \\  if (e.hidden !== true) return "ToBoolean(1)";
        \\  e.hidden = "";
        \\  if (e.hidden !== false) return "ToBoolean('')";
        \\  e.hidden = {};
        \\  if (e.hidden !== true) return "ToBoolean({})";
        \\  const p = doc.createElement("progress");
        \\  p.max = 5;
        \\  if (p.max !== 5) return "a number argument " + p.max;
        \\  p.max = { valueOf() { return 7; } };
        \\  if (p.max !== 7) return "valueOf " + p.max;
        \\  try { p.max = NaN; return "NaN into a restricted double"; } catch (err) { if (!(err instanceof TypeError)) return "NaN threw " + err; }
        \\  e.tabIndex = "3";
        \\  if (e.tabIndex !== 3) return "ToNumber('3') " + e.tabIndex;
        \\  const x = new XMLHttpRequest();
        \\  x.responseType = "bogus";
        \\  if (x.responseType !== "") return "an invalid enumeration value was not ignored: " + x.responseType;
        \\  x.responseType = "text";
        \\  if (x.responseType !== "text") return "an enumeration argument " + x.responseType;
    );
}

test "an interface argument: its instance, or a TypeError" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const c = doc.createElement("b");
        \\  if (e.appendChild(c) !== c) return "appendChild's result";
        \\  for (const bad of [{}, new Event("x"), "b", null]) {
        \\    try { e.appendChild(bad); return "appendChild(" + String(bad) + ") did not throw"; } catch (err) { if (!(err instanceof TypeError)) return "appendChild threw " + err; }
        \\  }
        \\  if (e.contains(null) !== false) return "a nullable interface argument";
    );
}

test "a receiver that is no instance: TypeError, or nothing for [LegacyLenientThis]" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const idSet = Object.getOwnPropertyDescriptor(Element.prototype, "id").set;
        \\  try { idSet.call({}, "x"); return "a setter on {} did not throw"; } catch (err) { if (!(err instanceof TypeError)) return "the setter threw " + err; }
        \\  try { Element.prototype.hasAttribute.call({}, "x"); return "an operation on {} did not throw"; } catch (err) { if (!(err instanceof TypeError)) return "the operation threw " + err; }
        \\  try { Element.prototype.hasAttribute.call(new Event("x"), "x"); return "an operation on an Event did not throw"; } catch (err) { if (!(err instanceof TypeError)) return "the operation threw " + err; }
        \\  const ready = Object.getOwnPropertyDescriptor(Document.prototype, "onreadystatechange");
        \\  ready.set.call({}, null);
        \\  if (ready.get.call({}) !== undefined) return "[LegacyLenientThis] getter";
        \\  idSet.call(e, "fine");
        \\  if (e.id !== "fine") return "the setter on its instance";
    );
}

test "no statement leaves a handle, on either path or when it throws" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("void e.id");
    try page.expectNoHandleLeftBy("e.id = 'x' + (k & 1)");
    try page.expectNoHandleLeftBy("e.id = { toString() { return 'o'; } }");
    try page.expectNoHandleLeftBy("e.id = Symbol()");
    try page.expectNoHandleLeftBy("void e.hasAttribute('title')");
    try page.expectNoHandleLeftBy("void e.getAttribute('missing')");
    try page.expectNoHandleLeftBy("e.setAttribute('data-k', 'v' + (k & 7))");
    try page.expectNoHandleLeftBy("e.setAttribute('data-k', { toString() { throw 1; } })");
    try page.expectNoHandleLeftBy("e.hidden = k & 1");
    try page.expectNoHandleLeftBy("e.tabIndex = k");
    try page.expectNoHandleLeftBy("void e.contains(null)");
    try page.expectNoHandleLeftBy("e.appendChild({})");
    try page.expectNoHandleLeftBy("Element.prototype.hasAttribute.call({}, 'x')");
    try page.expectNoHandleLeftBy("void new Response().type");
}
