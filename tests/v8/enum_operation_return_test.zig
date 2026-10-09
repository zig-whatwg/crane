//! An operation that returns a WebIDL enumeration gives script the String of
//! its value (WebIDL 3.2.24: "the result of converting an IDL enumeration type
//! value to an ECMAScript value is the String value that represents the same
//! sequence of code units as the enumeration value") - "" included.
//!
//! The binding's operation path (interface.zig, convertReturnValue) had no
//! case for an enum: it fell to its end-of-function fallback and returned
//! undefined, so `audio.canPlayType(type)` was undefined for every answer
//! while the attribute getter path converted enums correctly. Found by the
//! hostmedia lane (2026-10-09).
//!
//! The second half pins that fallback: every operation the generated
//! interfaces bind returns a kind convertReturnValue has a case for. A new
//! return kind with no case fails here instead of silently reaching script
//! as undefined.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// HTMLMediaElement.canPlayType's generated result type, CanPlayTypeResult -
/// "", "maybe", "probably" - taken from the generated operation itself.
const CanPlayTypeResult = @typeInfo(@typeInfo(@TypeOf(interfaces.HTMLMediaElement.call_canPlayType)).@"fn".return_type.?).error_union.payload;

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
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

/// Operations written as codegen writes them, returning the generated enum,
/// bound by the real V8Interface binding: what script calls goes through
/// convertReturnValue exactly as canPlayType does.
const Probe = struct {
    pub const Meta = struct {
        pub const name = "HmEnumReturnProbe";
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
            .{ "answer", "call_static_answer", 1 },
            .{ "nullableAnswer", "call_static_nullableAnswer", 1 },
            .{ "audio", "call_static_audio", 0 },
        };
        pub const own_methods = .{ "answer", "nullableAnswer", "audio" };
        pub const inherited_methods = .{};
        pub const eager_properties = .{};
        pub const lazy_properties = .{};
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, struct {});

    /// The value at `index` of CanPlayTypeResult.
    pub fn call_static_answer(_: *runtime.Instance, index: u32) anyerror!CanPlayTypeResult {
        return std.enums.values(CanPlayTypeResult)[index];
    }

    /// A nullable enum result: null past the last value.
    pub fn call_static_nullableAnswer(_: *runtime.Instance, index: u32) anyerror!?CanPlayTypeResult {
        const values = std.enums.values(CanPlayTypeResult);
        return if (index < values.len) values[index] else null;
    }

    /// A real HTMLAudioElement, for the generated canPlayType.
    pub fn call_static_audio(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return interfaces.HTMLAudioElement.call_constructor(instance.ctx);
    }
};

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

    const no_hooks: protocol.HostHooks = .{};

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
        defer std.testing.allocator.free(got);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        try std.testing.expectEqualStrings(expected, got);
    }
};

test "an operation returning an enum gives script each value's IDL string, \"\" included" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\JSON.stringify([0, 1, 2].map(i => HmEnumReturnProbe.answer(i)))
    , "[\"\",\"maybe\",\"probably\"]");
    try page.expect(
        \\[0, 1, 2].map(i => typeof HmEnumReturnProbe.answer(i)).join()
    , "string,string,string");
}

test "a nullable enum result is its IDL string, or null" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\JSON.stringify([0, 1, 2, 3].map(i => HmEnumReturnProbe.nullableAnswer(i)))
    , "[\"\",\"maybe\",\"probably\",null]");
}

test "the generated HTMLMediaElement.canPlayType reaches script as a string" {
    const page = try Page.open();
    defer page.close();
    // No Browser scope here: no media backend, so the answer is "".
    try page.expect(
        \\const audio = HmEnumReturnProbe.audio();
        \\[audio instanceof HTMLAudioElement, typeof audio.canPlayType('audio/wav'), JSON.stringify(audio.canPlayType('audio/wav'))].join()
    , "true,string,\"\"");
}

// =============================================================================
// The fallback: no bound operation reaches it
// =============================================================================

/// Whether convertReturnValue (src/runtime/engines/v8/interface.zig) has a
/// case for an operation returning `T` - the same checks, in its order. False
/// means its end-of-function fallback, which gives script undefined whatever
/// the operation returned; `*const anyopaque` is listed there explicitly, but
/// it too answers undefined, so it counts as unhandled here.
fn hasReturnCase(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info == .error_union) return hasReturnCase(info.error_union.payload);
    if (T == void) return true;
    if (info == .optional) return hasReturnCase(info.optional.child);
    if (T == *runtime.Instance) return true;
    if (T == bool) return true;
    if (T == i16 or T == i32 or T == i64 or T == u16 or T == u32 or T == u64) return true;
    if (T == f64 or T == f32) return true;
    if (T == runtime.DOMString) return true;
    if (T == []const u8) return true;
    if (T == runtime.JSValue) return true;
    if (T == webidl.ArrayBufferView) return true;
    if (info == .@"enum") return true;
    if (info == .@"union") return true;
    if (info == .@"struct") return true;
    return false;
}

const Walk = struct {
    /// Every `call_*` function examined.
    checked: usize,
    /// Those returning an enum (or a nullable one): the case this file adds.
    enums: usize,
    /// "Interface.call_x -> T" for each with no case.
    unhandled: []const []const u8,
};

/// Every `call_*` function the generated interfaces declare - regular,
/// static, overloads, mixin members by alias.
fn walkOperations() Walk {
    @setEvalBranchQuota(50_000_000);
    comptime var walk: Walk = .{ .checked = 0, .enums = 0, .unhandled = &.{} };
    inline for (comptime std.meta.declarations(interfaces)) |interface_decl| {
        const Interface = @field(interfaces, interface_decl.name);
        if (@TypeOf(Interface) != type) continue;
        if (@typeInfo(Interface) != .@"struct") continue;
        inline for (comptime std.meta.declarations(Interface)) |decl| {
            if (comptime !std.mem.startsWith(u8, decl.name, "call_")) continue;
            const function = @field(Interface, decl.name);
            const info = @typeInfo(@TypeOf(function));
            if (info != .@"fn") continue;
            const Return = info.@"fn".return_type orelse continue;
            walk.checked += 1;
            if (comptime isEnumResult(Return)) walk.enums += 1;
            if (comptime !hasReturnCase(Return)) {
                walk.unhandled = walk.unhandled ++ .{interface_decl.name ++ "." ++ decl.name ++ " -> " ++ @typeName(Return)};
            }
        }
    }
    return walk;
}

fn isEnumResult(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info == .error_union) return isEnumResult(info.error_union.payload);
    if (info == .optional) return isEnumResult(info.optional.child);
    return info == .@"enum";
}

test "every operation the generated interfaces bind returns a kind with a conversion" {
    const walk = comptime walkOperations();
    for (walk.unhandled) |entry| std.debug.print("no return conversion: {s}\n", .{entry});
    try std.testing.expectEqual(@as(usize, 0), walk.unhandled.len);
    // The walk is not vacuous: it saw the generated operations, and the
    // enum-returning ones (HTMLMediaElement.canPlayType,
    // Navigator.getAutoplayPolicy and its two overloads,
    // GPU.getPreferredCanvasFormat).
    try std.testing.expect(walk.checked > 1000);
    try std.testing.expectEqual(@as(usize, 5), walk.enums);
}

test "hasReturnCase's default: a kind convertReturnValue has no case for is unhandled" {
    // Pin the predicate's default, not only its known cases: an unknown kind
    // must count as reaching the fallback.
    try std.testing.expect(!hasReturnCase(u8));
    try std.testing.expect(!hasReturnCase(i8));
    try std.testing.expect(!hasReturnCase(usize));
    try std.testing.expect(!hasReturnCase(*const anyopaque));
    try std.testing.expect(!hasReturnCase(anyerror!?u8));
    try std.testing.expect(hasReturnCase(anyerror!CanPlayTypeResult));
    try std.testing.expect(hasReturnCase(anyerror!?CanPlayTypeResult));
}
