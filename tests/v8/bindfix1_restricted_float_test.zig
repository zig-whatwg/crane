//! WebIDL 3.2.5 `float` and 3.2.7 `double` - the restricted types - on every
//! path that converts one (lane bindfix1, Codex row 128 Q73):
//!
//!   "Let x be ? ToNumber(V). If x is NaN, +Infinity, or -Infinity, then
//!    throw a TypeError."
//!
//! Codegen maps `double` and `unrestricted double` both to f64, so the binding
//! learns which values are restricted from codegen's tables. Attributes and
//! (static) operations had one (`restricted_floats`); a constructor's
//! arguments and a namespace operation's had none, so `new CSSUnitValue(NaN,
//! "px")` and `CSS.px(Infinity)` made values Chrome and Safari refuse (the
//! integrator's probe Q48: both throw a TypeError for every non-finite
//! factory and constructor argument; Firefox ships no Typed OM).
//!
//! Each case runs through the real binding in a protocol Window realm, with
//! values made the way script makes them.
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

    /// `source` must evaluate to "ok" and report nothing; anything else is
    /// printed - it names the failing case.
    fn expectOk(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
        try testing.expectEqualStrings("ok", got);
    }
};

/// Script helpers every case uses: `rejects(f)` - f threw a TypeError;
/// `passes(f)` - f threw no TypeError (it returned, or the impl threw its own
/// error: on main CSSUnitValue's constructor and the CSS factories are
/// NotImplemented stubs, which the binding reaches only once every argument
/// has converted); `failures` - the names of the cases that did not hold.
const prelude =
    \\const failures = [];
    \\function rejects(f) { try { f(); } catch (e) { return e instanceof TypeError; } return false; }
    \\function passes(f) { try { f(); } catch (e) { return !(e instanceof TypeError); } return true; }
    \\const bad = [NaN, Infinity, -Infinity];
    \\
;

test "a sole constructor's restricted double argument: new CSSUnitValue(NaN, 'px') is a TypeError" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\for (const v of bad) if (!rejects(() => new CSSUnitValue(v, "px"))) failures.push("CSSUnitValue(" + v + ")");
        \\// Finite values, however large, convert.
        \\if (!passes(() => new CSSUnitValue(1e40, "px"))) failures.push("CSSUnitValue(1e40)");
        \\if (!passes(() => new CSSUnitValue(-0.5, "px"))) failures.push("CSSUnitValue(-0.5)");
        \\// The check is the argument's own conversion: the second argument is
        \\// not converted once the first has thrown.
        \\let converted = false;
        \\if (!rejects(() => new CSSUnitValue(NaN, { toString() { converted = true; return "px"; } }))) failures.push("CSSUnitValue order");
        \\if (converted) failures.push("CSSUnitValue converted its unit after a non-finite value");
        \\failures.join("; ") || "ok"
    );
}

test "a constructor's restricted double beside an unrestricted one: VTTCue(startTime, endTime, text)" {
    const page = try Page.open();
    defer page.close();
    // webvtt.idl: constructor(double startTime, unrestricted double endTime, DOMString text).
    try page.expectOk(prelude ++
        \\for (const v of bad) if (!rejects(() => new VTTCue(v, 1, "x"))) failures.push("VTTCue(" + v + ", 1)");
        \\for (const v of bad) if (rejects(() => new VTTCue(0, v, "x"))) failures.push("VTTCue(0, " + v + ") refused an unrestricted value");
        \\failures.join("; ") || "ok"
    );
}

test "an overloaded constructor's restricted float argument: new OfflineAudioContext(1, 1, NaN) is a TypeError" {
    const page = try Page.open();
    defer page.close();
    // webaudio.idl: constructor(OfflineAudioContextOptions contextOptions) and
    // constructor(unsigned long numberOfChannels, unsigned long length,
    // float sampleRate) - ConstructorArgs, through the overload resolution
    // algorithm. WebIDL 3.2.5 step 5: a finite double that rounds to 2^128
    // is a TypeError too.
    try page.expectOk(prelude ++
        \\for (const v of [...bad, 1e39]) if (!rejects(() => new OfflineAudioContext(1, 1, v))) failures.push("OfflineAudioContext(1, 1, " + v + ")");
        \\// A finite sample rate passes the conversion; what the constructor
        \\// does with it is not this test's (no TypeError from the binding).
        \\try { new OfflineAudioContext(1, 1, 44100); } catch (e) { if (e instanceof TypeError) failures.push("OfflineAudioContext(1, 1, 44100): " + e); }
        \\failures.join("; ") || "ok"
    );
}

test "a namespace operation's restricted double argument: CSS.px(Infinity) is a TypeError" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\const factories = ["number", "percent", "em", "px", "deg", "s", "Hz", "dpi", "fr", "cqmin", "Q"];
        \\for (const name of factories) {
        \\  for (const v of bad) if (!rejects(() => CSS[name](v))) failures.push("CSS." + name + "(" + v + ")");
        \\  if (!passes(() => CSS[name](1e40))) failures.push("CSS." + name + "(1e40)");
        \\}
        \\failures.join("; ") || "ok"
    );
}
