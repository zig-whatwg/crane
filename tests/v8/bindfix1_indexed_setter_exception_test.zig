//! An indexed property setter's exception is the assignment's (lane bindfix1,
//! Codex row 128 Q74).
//!
//! WebIDL 3.9.2 [[Set]] step 1.1.1 and 3.9.3 [[DefineOwnProperty]] step 1.3
//! "invoke the indexed property setter", whose last step runs the operation's
//! method steps: what they throw is the [[Set]]'s and the
//! [[DefineOwnProperty]]'s abrupt completion, in sloppy code too. The
//! interceptor answered kNo when the setter failed, so V8 went on to define an
//! ordinary own property `0` on the object and nothing was thrown; the definer
//! threw a TypeError whose message was the error's name instead of the
//! error itself. Blink converts and calls under one ExceptionState and returns
//! kYes on every path (bind_gen/interface.py,
//! make_indexed_property_setter_callback, chromium 23520b2ec9fc).
//!
//! The reaching interface on main: HTMLSelectElement's indexed setter (HTML
//! 4.10.7 "set the value of a new indexed property"), whose append is a
//! pre-insert that throws a HierarchyRequestError when the option is an
//! inclusive ancestor of the select - the same check add() makes.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
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
        try protocol.initializeEngine(.{});
        // Once per process, whichever file of tests/v8 gets here first.
        if (runtime.BrowserScope.standalone() == null) {
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(std.heap.page_allocator);
        }
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://bindfix1.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn expectOk(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
        try testing.expectEqualStrings("ok", got);
    }
};

/// A select inside the option the script tries to put into it, made fresh
/// for each case; `hierarchy(f)` - f threw a HierarchyRequestError
/// DOMException.
const prelude =
    \\const doc = new Document().implementation.createHTMLDocument("");
    \\function trap() {
    \\  const option = doc.createElement("option");
    \\  const select = doc.createElement("select");
    \\  option.appendChild(select);
    \\  return { option, select };
    \\}
    \\function hierarchy(f) {
    \\  try { f(); } catch (e) { return e instanceof DOMException && e.name === "HierarchyRequestError" ? true : String(e); }
    \\  return "nothing thrown";
    \\}
    \\const failures = [];
    \\function check(name, got, t) {
    \\  if (got !== true) failures.push(name + ": " + got);
    \\  if (Object.hasOwn(t.select, "0")) failures.push(name + ": an own property 0 was defined");
    \\  if (t.select.length !== 0) failures.push(name + ": length " + t.select.length);
    \\}
    \\
;

test "[[Set]] through an indexed setter throws the setter's exception, sloppy and strict" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\{ const t = trap(); check("sloppy select[0] =", hierarchy(() => { t.select[0] = t.option; }), t); }
        \\{ const t = trap(); check("strict select[0] =", hierarchy(() => { "use strict"; t.select[0] = t.option; }), t); }
        \\{ const t = trap(); check("Reflect.set", hierarchy(() => Reflect.set(t.select, 0, t.option)), t); }
        \\// HTMLOptionsCollection's setter: the select's own steps.
        \\{ const t = trap(); check("select.options[0] =", hierarchy(() => { t.select.options[0] = t.option; }), t); }
        \\// A setter that succeeds still sets, and defines nothing.
        \\{
        \\  const select = doc.createElement("select");
        \\  const option = doc.createElement("option");
        \\  select[0] = option;
        \\  if (select.length !== 1 || select[0] !== option || Object.getOwnPropertyDescriptor(select, "0").value !== option) failures.push("select[0] = option did not set it");
        \\}
        \\failures.join("; ") || "ok"
    );
}

test "[[DefineOwnProperty]] through an indexed setter throws the setter's own exception" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\{ const t = trap(); check("Object.defineProperty", hierarchy(() => Object.defineProperty(t.select, 0, { value: t.option })), t); }
        \\{ const t = trap(); check("Reflect.defineProperty", hierarchy(() => Reflect.defineProperty(t.select, 0, { value: t.option })), t); }
        \\// A value of the wrong interface is the conversion's TypeError.
        \\{
        \\  const select = doc.createElement("select");
        \\  let got;
        \\  try { Object.defineProperty(select, 0, { value: doc.createElement("div") }); } catch (e) { got = e; }
        \\  if (!(got instanceof TypeError)) failures.push("defineProperty with a div: " + got);
        \\}
        \\failures.join("; ") || "ok"
    );
}

test "a named setter's exception is the assignment's in sloppy code too: a computed style's CSS property" {
    const page = try Page.open();
    defer page.close();
    // CSSOM 6.7: a camel-cased attribute's setter invokes setProperty, and
    // "any exceptions thrown must be re-thrown" - a computed declaration is
    // read-only (css/cssom/computed-style-set-property.html). Crane's CSS
    // properties are named properties, whose setter swallowed the
    // NoModificationAllowedError in sloppy code.
    try page.expectOk(
        \\const doc = new Document().implementation.createHTMLDocument("");
        \\const div = doc.body.appendChild(doc.createElement("div"));
        \\const style = getComputedStyle(div);
        \\const failures = [];
        \\function readOnly(f) {
        \\  try { f(); } catch (e) { return e instanceof DOMException && e.name === "NoModificationAllowedError" ? true : String(e); }
        \\  return "nothing thrown";
        \\}
        \\let got = readOnly(() => { style.color = "blue"; });
        \\if (got !== true) failures.push("sloppy style.color =: " + got);
        \\got = readOnly(() => { "use strict"; style.color = "blue"; });
        \\if (got !== true) failures.push("strict style.color =: " + got);
        \\// A declaration that is not read-only takes the value, and throws nothing.
        \\div.style.color = "blue";
        \\if (div.style.color !== "blue") failures.push("div.style.color = " + div.style.color);
        \\failures.join("; ") || "ok"
    );
}
