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
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// A test-only interface whose static operations hand back what the binding
/// converted, so a case can read the IDL value itself: `unrestricted double`,
/// `double` (restricted, through the table codegen writes) and `long`.
const Echo = struct {
    pub const Meta = struct {
        pub const name = "BindfixNumberEcho";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        pub const exposed_in_all_contexts = true;
        pub const properties = .{};
        pub const methods = .{};
        pub const static_methods = .{
            .{ "unrestricted", "call_static_unrestricted", 1 },
            .{ "restricted", "call_static_restricted", 1 },
            .{ "long", "call_static_long", 1 },
        };
        pub const own_methods = .{ "unrestricted", "restricted", "long" };
        pub const inherited_methods = .{};
        pub const eager_properties = .{};
        pub const lazy_properties = .{};
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, struct {});

    /// `static double restricted(double x)`: the table codegen writes.
    pub const restricted_floats = .{.{ "call_static_restricted", 0b1 }};

    pub fn call_static_unrestricted(instance: *runtime.Instance, x: f64) anyerror!f64 {
        _ = instance;
        return x;
    }

    pub fn call_static_restricted(instance: *runtime.Instance, x: f64) anyerror!f64 {
        _ = instance;
        return x;
    }

    pub fn call_static_long(instance: *runtime.Instance, x: i32) anyerror!f64 {
        _ = instance;
        return @floatFromInt(x);
    }
};

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
        errdefer protocol.destroyWindowRealm(realm, .global_detached);
        const Install = struct {
            fn steps(data: ?*anyopaque) void {
                const r: runtime.Context = @ptrCast(@alignCast(data.?));
                const context: *ffi.Context = @ptrCast(@alignCast(r.engine_ctx.?));
                const current = ffi.v8_Isolate_GetCurrent() orelse return;
                v8.V8Interface(Echo).registerGlobal(current, context, Echo.Meta.name);
            }
        };
        try protocol.runInRealm(realm, Install.steps, realm);
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

test "ToNumber's cases through the binding: a Number is itself, every other value converts as before" {
    const page = try Page.open();
    defer page.close();
    // The fast path (a Number primitive converts with NumberValue alone) must
    // answer what ToNumber does, and every other value - a Number OBJECT
    // included - must still take the full path.
    try page.expectOk(prelude ++
        \\const E = BindfixNumberEcho;
        \\function same(name, got, want) { if (!Object.is(got, want)) failures.push(name + " = " + String(got) + (Object.is(got, -0) ? " (-0)" : "")); }
        \\function typeError(name, f) { const got = thrown(f); if (!(got instanceof TypeError)) failures.push(name + " threw " + got); }
        \\// Number primitives.
        \\same("unrestricted(5)", E.unrestricted(5), 5);
        \\same("unrestricted(NaN)", E.unrestricted(NaN), NaN);
        \\same("unrestricted(-0)", E.unrestricted(-0), -0);
        \\same("unrestricted(Infinity)", E.unrestricted(Infinity), Infinity);
        \\same("restricted(5)", E.restricted(5), 5);
        \\same("restricted(-0)", E.restricted(-0), -0);
        \\typeError("restricted(NaN)", () => E.restricted(NaN));
        \\typeError("restricted(Infinity)", () => E.restricted(Infinity));
        \\typeError("restricted(-Infinity)", () => E.restricted(-Infinity));
        \\same("long(5.7)", E.long(5.7), 5);
        \\same("long(-0)", E.long(-0), 0);
        \\// A Number OBJECT is an object: its valueOf runs.
        \\same("unrestricted(new Number(5))", E.unrestricted(new Number(5)), 5);
        \\const six = new Number(5); six.valueOf = () => 6;
        \\same("unrestricted(Number object, valueOf 6)", E.unrestricted(six), 6);
        \\same("long(Number object, valueOf 6)", E.long(six), 6);
        \\const nan = new Number(5); nan.valueOf = () => NaN;
        \\typeError("restricted(Number object, valueOf NaN)", () => E.restricted(nan));
        \\// Other primitives.
        \\same("unrestricted(\"7\")", E.unrestricted("7"), 7);
        \\same("long(\"7\")", E.long("7"), 7);
        \\same("unrestricted(true)", E.unrestricted(true), 1);
        \\same("unrestricted(null)", E.unrestricted(null), 0);
        \\same("unrestricted(undefined)", E.unrestricted(undefined), NaN);
        \\typeError("unrestricted(10n)", () => E.unrestricted(10n));
        \\typeError("long(10n)", () => E.long(10n));
        \\typeError("unrestricted(Symbol())", () => E.unrestricted(Symbol()));
        \\// An object whose valueOf throws: script's own exception.
        \\expectMine("unrestricted(throwing)", () => E.unrestricted(throwing));
        \\expectMine("restricted(throwing)", () => E.restricted(throwing));
        \\expectMine("long(throwing)", () => E.long(throwing));
        \\failures.join("; ") || "ok"
    );
}
