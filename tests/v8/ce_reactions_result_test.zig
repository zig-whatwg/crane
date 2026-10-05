//! A [CEReactions] operation whose result is a platform object, through the
//! real binding (codex-ce Q28): the member computes its result, then the
//! bracket's `end` runs reactions - script - and only then does the binding
//! convert the result, reading its vtable and its realm. A reaction that ends
//! the result's realm frees it (a detached clone, a createElement result),
//! and the wrapper an Owned roots does not keep the Instance. So codegen runs
//! `end` explicitly between two reads of the result's slab generation
//! (writer.zig, writeCEReactionsGuardedCall), and a result freed meanwhile is
//! an InvalidStateError - never a stale pointer the binding then reads.
//!
//! The probe's operation is written exactly as codegen writes one, with a
//! bracket whose `end` frees the result when asked - what a reaction that
//! ends the result's realm does to it. A protocol agent's Window realm, so
//! DOMException is there to be thrown.

const std = @import("std");
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
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

/// What the probe's bracket does at `end`, and what it saw.
const Probe = struct {
    /// `end` frees the result, as a reaction that ends its realm does.
    var free_at_end: bool = false;
    var made: ?*runtime.Instance = null;

    pub const Meta = struct {
        pub const name = "BceCEReactionsResultProbe";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        pub const exposed_in_all_contexts = true;
        pub const properties = .{};
        pub const methods = .{};
        pub const static_methods = .{.{ "make", "call_static_make", 0 }};
        pub const own_methods = .{"make"};
        pub const inherited_methods = .{};
        pub const eager_properties = .{};
        pub const lazy_properties = .{};
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, struct {});
    pub const ce_reactions = .{"call_static_make"};

    const Scope = struct {
        result: ?*runtime.Instance = null,

        fn end(self: *Scope) void {
            const result = self.result orelse return;
            if (free_at_end) runtime.Instance.deinit(result);
        }
    };

    fn impl(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const element = try interfaces.HTMLElement.call_constructor(instance.ctx);
        made = element;
        return element;
    }

    /// As writeCEReactionsGuardedCall writes a [CEReactions] operation that
    /// returns a platform object, with the probe's Scope for runtime.CEReactions.
    pub fn call_static_make(instance: *runtime.Instance) anyerror!*runtime.Instance {
        var ce_scope: Scope = .{};
        const result = impl(instance) catch |err| {
            ce_scope.end();
            return err;
        };
        ce_scope.result = result;
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        ce_scope.end();
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
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
        // The probe on the realm's global.
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

test "a result its reactions freed is an InvalidStateError, never a stale pointer" {
    const page = try Page.open();
    defer page.close();
    Probe.free_at_end = true;
    defer Probe.free_at_end = false;
    try page.expect(
        \\try { BceCEReactionsResultProbe.make(); "returned" }
        \\catch (e) { e instanceof DOMException && e.name === "InvalidStateError" ? "InvalidStateError" : String(e) }
    , "InvalidStateError");
    // The binding never wrapped it.
    try std.testing.expect(Probe.made != null);
}

test "a result the reactions left alone is returned and wrapped" {
    const page = try Page.open();
    defer page.close();
    Probe.free_at_end = false;
    try page.expect("String(BceCEReactionsResultProbe.make() instanceof HTMLElement)", "true");
    try std.testing.expect(protocol.hasWrapper(Probe.made.?));
}
