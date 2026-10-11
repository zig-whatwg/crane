//! No binding call keeps a handle once it has returned.
//!
//! Every `v8_*` call that returns a pointer allocates a Global the caller
//! owns: the receiver (`info.getThis()`), each argument (`info.get(i)`), the
//! contexts, and every value made for the result (`setReturnValue` copies it
//! into the call's return slot). One left behind per call is one per call for
//! the agent's life. These tests run a statement through the real binding 64
//! times and read V8's own live count, `v8_Isolate_GetGlobalHandleBytes`
//! (docs/lessons/testing-a-handle-leak-test-needs-v8-s-live-count.md), against
//! the same loop run once already, so what the first calls make and later ones
//! reuse is not counted.
//!
//! The first group pins paths that were already clean, one per kind of
//! callback (operation, attribute getter and setter, the named and indexed
//! interceptors, a static operation, a mixin member, a stringifier). They
//! guard against a regression; they were green before the fixes below.
//!
//! The second group was red until the leaks were fixed (lane callleak; gc_bench
//! with --c-alloc read +32 B of global handles per call for each):
//! - a namespace operation never released its arguments (`CSS.escape("a")`),
//!   nor the undefined it made for a void result (`console.groupEnd()`);
//! - an attribute setter whose value converts to something that does not refer
//!   to its handle - a null EventHandler, a boolean `any` - kept the handle;
//! - a [PutForwards] setter, and a setter given a value outside its
//!   enumeration, kept the undefined it set as its result.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
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

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
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

    /// Runs `source`, which must answer "ok" and report nothing.
    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        try testing.expectEqualStrings("ok", got);
    }

    /// The global handle bytes 64 runs of `statement` leave once a first
    /// round has made what later ones reuse. `e` is a div of an HTML
    /// document (the realm has no `document`) with a title, a class list, a
    /// data attribute and a child; the loop's `k` counts.
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop =
            \\(() => {
            \\  var e = globalThis.probe ||= (() => {
            \\    var doc = new Document().implementation.createHTMLDocument("");
            \\    var d = doc.createElement("div");
            \\    d.setAttribute("title", "x");
            \\    d.className = "a b";
            \\    d.dataset.foo = "1";
            \\    d.appendChild(doc.createElement("span"));
            \\    return d;
            \\  })();
            \\  for (var k = 0; k < 64; k++) {
        ++ statement ++
            \\;
            \\  }
            \\  return "ok";
            \\})()
        ;
        try self.run(loop);
        try self.collect();
        const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        try self.run(loop);
        try self.collect();
        const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        return after - before;
    }

    fn expectNoHandleLeftBy(self: Page, comptime statement: []const u8) !void {
        const left = try self.handleBytesLeftBy(statement);
        if (left > 0) {
            std.debug.print("{s}: {d} global handle bytes left over 64 calls\n", .{ statement, left });
            return error.HandleLeftPerCall;
        }
    }
};

// ---- paths that were already clean ----

test "the control: a statement that reaches no binding" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("Math.abs(k)");
}

test "an operation with a string argument and a boolean result" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.hasAttribute('title')");
}

test "an operation with a string result" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.getAttribute('title')");
}

test "an attribute getter and setter with a string value" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.title");
    try page.expectNoHandleLeftBy("e.title = 'x'");
}

test "the named and indexed interceptors" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.dataset.foo");
    try page.expectNoHandleLeftBy("e.dataset.foo = '1'");
    try page.expectNoHandleLeftBy("e.childNodes[0]");
    try page.expectNoHandleLeftBy("e.classList[0]");
}

test "a static operation" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("URL.canParse('https://a.test/')");
}

test "a mixin member" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.firstElementChild");
    try page.expectNoHandleLeftBy("e.matches('div')");
}

test "a stringifier" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("String(e.classList)");
}

test "an event handler attribute set to a function, then read" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.onclick = (globalThis.handler ||= function () {})");
    try page.expectNoHandleLeftBy("e.onclick");
}

// ---- paths that kept a handle per call ----

test "a namespace operation releases its argument" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("CSS.escape('a')");
}

test "a namespace operation releases each of its arguments" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("CSS.supports('color', 'red')");
}

test "a namespace operation releases an object argument once it returns" {
    const page = try Page.open();
    defer page.close();
    // An `any` (runtime.JSValue): the object's own handle, borrowed by the
    // impl for the call. CSS.registerProperty is a NotImplemented stub: the
    // namespace binding hands back an Error object for it (it does not
    // throw - a gap of its own), whose message string was kept too.
    try page.expectNoHandleLeftBy("try { CSS.registerProperty({ name: '--x' }); } catch (err) {}");
}

test "a namespace operation that returns nothing makes no handle for it" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("console.groupEnd()");
}

test "an event handler attribute set to null releases the value" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.onclick = null");
}

test "an any-typed attribute set to a primitive releases the value" {
    const page = try Page.open();
    defer page.close();
    // HTMLElement.hidden: (boolean or unrestricted double or DOMString)?,
    // typed ?any (runtime.JSValue) in the binding.
    try page.expectNoHandleLeftBy("e.hidden = false");
    try page.expectNoHandleLeftBy("e.hidden = 'until-found'");
    try page.expectNoHandleLeftBy("e.hidden = null");
}

test "an enum attribute set outside its enumeration releases what it made" {
    const page = try Page.open();
    defer page.close();
    // WebIDL 3.2.24 for an attribute: an invalid enumeration value is ignored.
    try page.expectNoHandleLeftBy("(globalThis.xhr ||= new XMLHttpRequest()).responseType = 'bogus'");
}

test "a [PutForwards] setter releases what it made" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("e.classList = 'a b'");
    try page.expectNoHandleLeftBy("e.style = 'color: red'");
}

test "an observable array's traps release what they are given and make" {
    const page = try Page.open();
    defer page.close();
    // DocumentOrShadowRoot.adoptedStyleSheets: a Proxy whose traps are
    // native (observable_array.zig). Each trap took its target, key and
    // receiver as owned Globals and kept them, and kept the value it set as
    // its result.
    const sheets = "(globalThis.sheets ||= new Document().adoptedStyleSheets)";
    try page.expectNoHandleLeftBy(sheets ++ ".length");
    try page.expectNoHandleLeftBy(sheets ++ "[0]");
    try page.expectNoHandleLeftBy(sheets ++ ".foo = 1");
    try page.expectNoHandleLeftBy(sheets ++ ".foo");
    try page.expectNoHandleLeftBy("delete " ++ sheets ++ ".foo");
    try page.expectNoHandleLeftBy("Object.getPrototypeOf(" ++ sheets ++ ")");
    // These two throw today (the traps break the Proxy invariants for
    // `length`, a gap of its own); the handles must go either way.
    try page.expectNoHandleLeftBy("try { Object.keys(" ++ sheets ++ "); } catch (err) {}");
    try page.expectNoHandleLeftBy("try { Object.getOwnPropertyDescriptor(" ++ sheets ++ ", 'length'); } catch (err) {}");
}

test "an operation returning a union releases the string its member made" {
    const page = try Page.open();
    defer page.close();
    // FormData.get returns FormDataEntryValue? = (File or USVString)?: the
    // union went to conv.toV8Value with `owned` left false, so the String
    // made for a USVString member was kept - 16-32 B per call (Codex row
    // 19, Q13). A File member is its wrapper, the wrapper cache's.
    const form = "(globalThis.form ||= (() => { const f = new FormData(); f.append('a', 'b'); f.append('f', new Blob(['x'])); return f; })())";
    try page.expectNoHandleLeftBy(form ++ ".get('a')");
    try page.expectNoHandleLeftBy(form ++ ".get('f')");
    try page.expectNoHandleLeftBy(form ++ ".get('missing')");
}
