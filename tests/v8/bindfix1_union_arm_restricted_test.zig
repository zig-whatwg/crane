//! A union's restricted `double` or `float` arm (lane bindfix1, Codex row 128
//! Q78).
//!
//! WebIDL 3.2.25, converting V to a union: a Number goes to the numeric arm
//! (step 13), and an object no other arm takes to it too (step 17) - "the
//! result of converting V to that numeric type", the arm's own conversion.
//! For a `double` arm that is 3.2.7: NaN and the infinities are a TypeError.
//! Blink's union conversion converts each arm with that arm's own
//! NativeValueTraits (IDLDouble -> ToRestrictedDouble,
//! bindings/core/v8/native_value_traits_impl.h, chromium 23520b2ec9fc).
//! CSSNumberish - typedef (double or CSSNumericValue) - took NaN and the
//! infinities, as raw numbers and from valueOf: codegen marked restricted
//! floats only for plain arguments and attributes.
//!
//! The probe is test-only: static operations and an attribute whose
//! parameters are the GENERATED union typedefs (CSSNumberish, and MLNumber -
//! (bigint or unrestricted double) - whose double arm is unrestricted), so the
//! cases do not depend on any impl of the CSS math values.
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

const CSSNumberish = v8.conversions.generated_typedefs.CSSNumberish;
const MLNumber = v8.conversions.generated_typedefs.MLNumber;

/// What a CSSNumberish converted to: its double, or -1 for a CSSNumericValue.
fn numberOf(value: CSSNumberish) f64 {
    return switch (value) {
        .double => |d| d,
        .cssnumeric_value => -1,
    };
}

const Probe = struct {
    pub const Meta = struct {
        pub const name = "BindfixNumberishProbe";
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
            .{ "one", "call_static_one", 1 },
            .{ "maybe", "call_static_maybe", 1 },
            .{ "many", "call_static_many", 0 },
            .{ "unrestricted", "call_static_unrestricted", 1 },
        };
        pub const own_methods = .{ "one", "maybe", "many", "unrestricted" };
        pub const inherited_methods = .{};
        pub const eager_properties = .{};
        pub const lazy_properties = .{};
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, struct {});

    /// `static double one(CSSNumberish value)`.
    pub fn call_static_one(instance: *runtime.Instance, value: CSSNumberish) anyerror!f64 {
        _ = instance;
        return numberOf(value);
    }

    /// `static double maybe(CSSNumberish? value)`: -2 for null.
    pub fn call_static_maybe(instance: *runtime.Instance, value: ?CSSNumberish) anyerror!f64 {
        _ = instance;
        return if (value) |present| numberOf(present) else -2;
    }

    /// `static double many(CSSNumberish... values)`: their sum.
    pub fn call_static_many(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!f64 {
        _ = instance;
        var sum: f64 = 0;
        for (values) |value| sum += numberOf(value);
        return sum;
    }

    /// `static unrestricted double unrestricted(MLNumber value)`.
    pub fn call_static_unrestricted(instance: *runtime.Instance, value: MLNumber) anyerror!f64 {
        _ = instance;
        return switch (value) {
            .double => |d| d,
            .bigint => -1,
        };
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
                const isolate = ffi.v8_Isolate_GetCurrent() orelse return;
                v8.V8Interface(Probe).registerGlobal(isolate, context, Probe.Meta.name);
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

const prelude =
    \\const P = BindfixNumberishProbe;
    \\const failures = [];
    \\function rejects(f) { try { f(); } catch (e) { return e instanceof TypeError; } return false; }
    \\const bad = [NaN, Infinity, -Infinity];
    \\const valueOf = (v) => ({ valueOf() { return v; } });
    \\
;

test "a union's restricted double arm refuses NaN and the infinities, as numbers and from valueOf" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\for (const v of bad) {
        \\  if (!rejects(() => P.one(v))) failures.push("one(" + v + ")");
        \\  if (!rejects(() => P.one(valueOf(v)))) failures.push("one(valueOf " + v + ")");
        \\}
        \\if (P.one(1e40) !== 1e40) failures.push("one(1e40)");
        \\if (P.one(-0.5) !== -0.5) failures.push("one(-0.5)");
        \\failures.join("; ") || "ok"
    );
}

test "a nullable and a variadic union argument check each value's restricted arm" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\for (const v of bad) if (!rejects(() => P.maybe(v))) failures.push("maybe(" + v + ")");
        \\if (P.maybe(null) !== -2 || P.maybe(3) !== 3) failures.push("maybe(null/3)");
        \\for (const v of bad) {
        \\  if (!rejects(() => P.many(v))) failures.push("many(" + v + ")");
        \\  if (!rejects(() => P.many(1, 2, v))) failures.push("many(1, 2, " + v + ")");
        \\  if (!rejects(() => P.many(1, valueOf(v), 2))) failures.push("many(1, valueOf " + v + ", 2)");
        \\}
        \\if (P.many() !== 0 || P.many(1, 2, 3) !== 6) failures.push("many(finite)");
        \\// Each argument's conversion is its own: nothing after a refused one runs.
        \\let later = false;
        \\if (!rejects(() => P.many(NaN, { valueOf() { later = true; return 1; } }))) failures.push("many(NaN, later)");
        \\if (later) failures.push("many converted an argument after a refused one");
        \\failures.join("; ") || "ok"
    );
}

test "an unrestricted double arm still takes NaN and the infinities" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\if (!Number.isNaN(P.unrestricted(NaN))) failures.push("unrestricted(NaN)");
        \\if (P.unrestricted(Infinity) !== Infinity || P.unrestricted(-Infinity) !== -Infinity) failures.push("unrestricted(+-Infinity)");
        \\failures.join("; ") || "ok"
    );
}

test "codegen marks a union's restricted arms on the generated union" {
    // CSSNumberish (double or CSSNumericValue): its double arm is restricted.
    if (comptime !@hasDecl(CSSNumberish, "restricted_arms")) {
        return error.CSSNumberishHasNoRestrictedArms;
    } else {
        try testing.expectEqual(@as(usize, 1), CSSNumberish.restricted_arms.len);
        try testing.expectEqualStrings("double", CSSNumberish.restricted_arms[0]);
    }
    // MLNumber (bigint or unrestricted double): none.
    try testing.expect(!@hasDecl(MLNumber, "restricted_arms"));
}
