//! No Intl call keeps a handle once it has returned, and no Intl object keeps
//! one once it is collected.
//!
//! intl_binding.zig is native glue over the pure Zig Intl library, and every
//! `v8_*` call that returns a pointer allocates a Global the caller owns: the
//! receiver (`info.getThis()`), each argument (`info.get(i)`), the context,
//! every key, every `Object::Get` result and every value made for the result
//! (`setReturnValue` copies it into the call's return slot). Lane callleak
//! measured, with gc_bench --c-alloc and V8's own count of global handle
//! bytes, +160 B per `collator.compare(a, b)` (the "__collatorIdx" key, its
//! Get result, both arguments, the Integer result), +96 B per
//! `numberFormat.format(k)`, +192 B per `dateTimeFormat.format(0)` and +224 B
//! of handles per `new Intl.Collator()`, whose object was never collected.
//!
//! These tests run a statement through the real binding 64 times and read
//! V8's own live count, `v8_Isolate_GetGlobalHandleBytes`
//! (docs/lessons/testing-a-handle-leak-test-needs-v8-s-live-count.md), against
//! the same loop run once already, so what the first calls make and later
//! ones reuse is not counted. A constructor's statement makes a new object
//! each time and drops it: once collected, it must leave no handle either.
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
        if (!std.mem.eql(u8, "ok", got)) {
            std.debug.print("{s}\n  answered: {s}\n", .{ source, got });
            return error.UnexpectedAnswer;
        }
    }

    /// The global handle bytes 64 runs of `statement` leave once a first
    /// round has made what later ones reuse. The loop's `k` counts; Intl
    /// objects a statement reuses are made once, on `globalThis`.
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop =
            \\(() => {
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

    /// Every statement in `statements` leaves no handle; the ones that do
    /// are all printed before the test fails.
    fn expectNoHandleLeftByEach(self: Page, comptime statements: []const []const u8) !void {
        var failed: usize = 0;
        inline for (statements) |statement| {
            const left = try self.handleBytesLeftBy(statement);
            if (left > 0) {
                std.debug.print("{s}: {d} global handle bytes left over 64 calls\n", .{ statement, left });
                failed += 1;
            }
        }
        if (failed > 0) return error.HandleLeftPerCall;
    }
};

test "the control: a statement that reaches no binding" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftByEach(&.{"Math.abs(k)"});
}

test "Intl.DateTimeFormat's operations release what they take and make" {
    const page = try Page.open();
    defer page.close();
    const dtf = "(globalThis.dtf ||= new Intl.DateTimeFormat('en', { dateStyle: 'medium' }))";
    try page.expectNoHandleLeftByEach(&.{
        dtf ++ ".format(0)",
        dtf ++ ".format()",
        dtf ++ ".format(globalThis.day ||= new Date(0))",
        dtf ++ ".formatToParts(0)",
        dtf ++ ".resolvedOptions()",
        "Intl.DateTimeFormat.supportedLocalesOf('en')",
    });
}

test "Intl.NumberFormat's operations release what they take and make" {
    const page = try Page.open();
    defer page.close();
    const nf = "(globalThis.nf ||= new Intl.NumberFormat('en', { style: 'currency', currency: 'EUR' }))";
    try page.expectNoHandleLeftByEach(&.{
        nf ++ ".format(k)",
        nf ++ ".formatToParts(-k - 0.5)",
        nf ++ ".resolvedOptions()",
        "Intl.NumberFormat.supportedLocalesOf('en')",
    });
}

test "Intl.Collator's operations release what they take and make" {
    const page = try Page.open();
    defer page.close();
    const collator = "(globalThis.collator ||= new Intl.Collator('en', { sensitivity: 'base' }))";
    try page.expectNoHandleLeftByEach(&.{
        collator ++ ".compare('a', 'b')",
        collator ++ ".compare('B', 'a')",
        collator ++ ".compare('a')",
        collator ++ ".resolvedOptions()",
        "Intl.Collator.supportedLocalesOf('en')",
    });
}

test "Intl.PluralRules', RelativeTimeFormat's and ListFormat's operations release what they take and make" {
    const page = try Page.open();
    defer page.close();
    const pr = "(globalThis.pr ||= new Intl.PluralRules('en', { type: 'ordinal' }))";
    const rtf = "(globalThis.rtf ||= new Intl.RelativeTimeFormat('en', { numeric: 'auto' }))";
    const lf = "(globalThis.lf ||= new Intl.ListFormat('en', { type: 'disjunction' }))";
    try page.expectNoHandleLeftByEach(&.{
        pr ++ ".select(k)",
        pr ++ ".resolvedOptions()",
        "Intl.PluralRules.supportedLocalesOf('en')",
        rtf ++ ".format(-1, 'day')",
        rtf ++ ".format(3, 'weeks')",
        "try { " ++ rtf ++ ".format(1, 'fortnight'); } catch (e) {}",
        rtf ++ ".resolvedOptions()",
        "Intl.RelativeTimeFormat.supportedLocalesOf('en')",
        lf ++ ".format(['a', 'b', k])",
        lf ++ ".format([])",
        lf ++ ".resolvedOptions()",
        "Intl.ListFormat.supportedLocalesOf('en')",
    });
}

test "Intl.DisplayNames' and Intl.Segmenter's operations release what they take and make" {
    const page = try Page.open();
    defer page.close();
    const dn = "(globalThis.dn ||= new Intl.DisplayNames('en', { type: 'region', fallback: 'none' }))";
    const seg = "(globalThis.seg ||= new Intl.Segmenter('en', { granularity: 'word' }))";
    const segments = "(globalThis.segments ||= " ++ seg ++ ".segment('a b'))";
    try page.expectNoHandleLeftByEach(&.{
        dn ++ ".of('US')",
        dn ++ ".of('ZZ')",
        dn ++ ".resolvedOptions()",
        "Intl.DisplayNames.supportedLocalesOf('en')",
        seg ++ ".segment('a b')",
        "for (const s of " ++ segments ++ ") {}",
        segments ++ ".containing(0)",
        segments ++ ".containing(99)",
        seg ++ ".resolvedOptions()",
        "Intl.Segmenter.supportedLocalesOf('en')",
    });
}

test "Intl.Locale's accessors and operations release what they take and make" {
    const page = try Page.open();
    defer page.close();
    const locale = "(globalThis.locale ||= new Intl.Locale('en-US', { calendar: 'gregory', numeric: true }))";
    try page.expectNoHandleLeftByEach(&.{
        locale ++ ".baseName()",
        locale ++ ".language()",
        locale ++ ".script()",
        locale ++ ".region()",
        locale ++ ".calendar()",
        locale ++ ".numeric()",
        locale ++ ".toString()",
        locale ++ ".maximize()",
        locale ++ ".minimize()",
        locale ++ ".getCalendars()",
        locale ++ ".getTimeZones()",
        locale ++ ".getTextInfo()",
        locale ++ ".getWeekInfo()",
    });
}

test "Intl.supportedValuesOf and the toLocaleString methods release what they take and make" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftByEach(&.{
        "Intl.supportedValuesOf('calendar')",
        "try { Intl.supportedValuesOf('bogus'); } catch (e) {}",
        "(k + 0.5).toLocaleString('de', { style: 'percent' })",
        "(globalThis.day ||= new Date(0)).toLocaleString('en', { dateStyle: 'short', timeStyle: 'short' })",
        "(globalThis.day ||= new Date(0)).toLocaleDateString('en', { dateStyle: 'long' })",
        "(globalThis.day ||= new Date(0)).toLocaleTimeString('en', { timeStyle: 'short' })",
    });
}

test "an Intl object leaves no handle once it is collected" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftByEach(&.{
        "void new Intl.DateTimeFormat('en', { dateStyle: 'full', timeStyle: 'short' })",
        "void new Intl.NumberFormat('en', { style: 'currency', currency: 'USD', minimumFractionDigits: 1 })",
        "void new Intl.Collator('en', { sensitivity: 'base', numeric: true, caseFirst: 'upper' })",
        "void new Intl.PluralRules('en', { type: 'ordinal' })",
        "void new Intl.RelativeTimeFormat('en', { style: 'short', numeric: 'auto' })",
        "void new Intl.ListFormat('en', { type: 'unit', style: 'narrow' })",
        "void new Intl.DisplayNames('en', { type: 'language', style: 'short', fallback: 'none' })",
        "void new Intl.Segmenter('en', { granularity: 'sentence' })",
        "void new Intl.Locale('en-Latn-US-u-ca-gregory', { numeric: true, hourCycle: 'h12' })",
        "void new Intl.Locale('en').maximize()",
        "void new Intl.Segmenter().segment('abc')",
        "try { new Intl.Locale(); } catch (e) {}",
    });
}
