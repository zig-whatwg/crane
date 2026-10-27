//! WebIDL's numeric conversions begin "Let x be ? ToNumber(V)" (3.2.4
//! ConvertToInt step 4 via 3.2.4.x, 3.2.5-3.2.8 step 1): when V is an object
//! whose valueOf or toString throws, that abrupt completion is the
//! conversion's - the operation, setter or constructor never runs, and script
//! catches its own exception (lane bindfix1).
//!
//! The binding read the number with v8::Value::NumberValue(...).FromMaybe(0):
//! a throw answered 0 with the exception left pending, so the call ran with
//! 0 (a setter stored it) and script then caught the exception - or, where
//! the call threw an error of its own, that error instead (`CSS.px` is a
//! NotImplemented stub on main: it threw NotSupportedError over script's
//! exception). Primitives cannot run script, so only an object's conversion
//! is run under a catch.
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

/// `thrown(f)` - what f threw (undefined for nothing); `mine` - the object
/// every throwing valueOf throws.
const prelude =
    \\const failures = [];
    \\const mine = new RangeError("mine");
    \\const throwing = { valueOf() { throw mine; } };
    \\function thrown(f) { try { f(); } catch (e) { return e; } return undefined; }
    \\function expectMine(name, f) { const got = thrown(f); if (got !== mine) failures.push(name + " threw " + got); }
    \\
;

test "a numeric argument whose valueOf throws: the call does not run, and script catches its own exception" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\// A namespace operation's restricted double (CSS.px is a stub on main:
        \\// it ran and threw NotSupportedError over script's exception).
        \\expectMine("CSS.px", () => CSS.px(throwing));
        \\// A constructor's restricted double, then the arguments after it.
        \\let later = false;
        \\expectMine("new VTTCue", () => new VTTCue(throwing, { valueOf() { later = true; return 1; } }, "x"));
        \\if (later) failures.push("VTTCue converted endTime after startTime threw");
        \\failures.join("; ") || "ok"
    );
}

test "a numeric attribute value whose valueOf throws: the setter does not run" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\const doc = new Document().implementation.createHTMLDocument("");
        \\// `long tabIndex`: ConvertToInt's ToNumber.
        \\const div = doc.createElement("div");
        \\div.tabIndex = 5;
        \\expectMine("tabIndex =", () => { div.tabIndex = throwing; });
        \\if (div.tabIndex !== 5 || div.getAttribute("tabindex") !== "5") failures.push("tabIndex set to " + div.tabIndex);
        \\// `double value` (HTMLProgressElement).
        \\const progress = doc.createElement("progress");
        \\progress.max = 10;
        \\progress.value = 3;
        \\expectMine("progress.value =", () => { progress.value = throwing; });
        \\if (progress.value !== 3) failures.push("progress.value set to " + progress.value);
        \\// `unrestricted double valueAsNumber` (HTMLInputElement, type=number).
        \\const input = doc.createElement("input");
        \\input.type = "number";
        \\input.valueAsNumber = 5;
        \\expectMine("valueAsNumber =", () => { input.valueAsNumber = throwing; });
        \\if (input.value !== "5") failures.push("valueAsNumber set the value to " + input.value);
        \\// A Symbol is ToNumber's own TypeError, as before.
        \\const symbol = thrown(() => { progress.value = Symbol(); });
        \\if (!(symbol instanceof TypeError) || progress.value !== 3) failures.push("progress.value = Symbol() threw " + symbol);
        \\failures.join("; ") || "ok"
    );
}
