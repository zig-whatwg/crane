//! Generated from: navigation-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceTimingImpl = @import("impls").PerformanceTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const PerformanceTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "navigationStart", "get_navigationStart", null },
            .{ "unloadEventStart", "get_unloadEventStart", null },
            .{ "unloadEventEnd", "get_unloadEventEnd", null },
            .{ "redirectStart", "get_redirectStart", null },
            .{ "redirectEnd", "get_redirectEnd", null },
            .{ "fetchStart", "get_fetchStart", null },
            .{ "domainLookupStart", "get_domainLookupStart", null },
            .{ "domainLookupEnd", "get_domainLookupEnd", null },
            .{ "connectStart", "get_connectStart", null },
            .{ "connectEnd", "get_connectEnd", null },
            .{ "secureConnectionStart", "get_secureConnectionStart", null },
            .{ "requestStart", "get_requestStart", null },
            .{ "responseStart", "get_responseStart", null },
            .{ "responseEnd", "get_responseEnd", null },
            .{ "domLoading", "get_domLoading", null },
            .{ "domInteractive", "get_domInteractive", null },
            .{ "domContentLoadedEventStart", "get_domContentLoadedEventStart", null },
            .{ "domContentLoadedEventEnd", "get_domContentLoadedEventEnd", null },
            .{ "domComplete", "get_domComplete", null },
            .{ "loadEventStart", "get_loadEventStart", null },
            .{ "loadEventEnd", "get_loadEventEnd", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "navigationStart", "get_navigationStart", null },
            .{ "unloadEventStart", "get_unloadEventStart", null },
            .{ "unloadEventEnd", "get_unloadEventEnd", null },
            .{ "redirectStart", "get_redirectStart", null },
            .{ "redirectEnd", "get_redirectEnd", null },
            .{ "fetchStart", "get_fetchStart", null },
            .{ "domainLookupStart", "get_domainLookupStart", null },
            .{ "domainLookupEnd", "get_domainLookupEnd", null },
            .{ "connectStart", "get_connectStart", null },
            .{ "connectEnd", "get_connectEnd", null },
            .{ "secureConnectionStart", "get_secureConnectionStart", null },
            .{ "requestStart", "get_requestStart", null },
            .{ "responseStart", "get_responseStart", null },
            .{ "responseEnd", "get_responseEnd", null },
            .{ "domLoading", "get_domLoading", null },
            .{ "domInteractive", "get_domInteractive", null },
            .{ "domContentLoadedEventStart", "get_domContentLoadedEventStart", null },
            .{ "domContentLoadedEventEnd", "get_domContentLoadedEventEnd", null },
            .{ "domComplete", "get_domComplete", null },
            .{ "loadEventStart", "get_loadEventStart", null },
            .{ "loadEventEnd", "get_loadEventEnd", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            navigationStart: u64 = undefined,
            unloadEventStart: u64 = undefined,
            unloadEventEnd: u64 = undefined,
            redirectStart: u64 = undefined,
            redirectEnd: u64 = undefined,
            fetchStart: u64 = undefined,
            domainLookupStart: u64 = undefined,
            domainLookupEnd: u64 = undefined,
            connectStart: u64 = undefined,
            connectEnd: u64 = undefined,
            secureConnectionStart: u64 = undefined,
            requestStart: u64 = undefined,
            responseStart: u64 = undefined,
            responseEnd: u64 = undefined,
            domLoading: u64 = undefined,
            domInteractive: u64 = undefined,
            domContentLoadedEventStart: u64 = undefined,
            domContentLoadedEventEnd: u64 = undefined,
            domComplete: u64 = undefined,
            loadEventStart: u64 = undefined,
            loadEventEnd: u64 = undefined,
            _internal: ?*PerformanceTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceTimingToJSON = struct {
        navigationStart: u64,
        unloadEventStart: u64,
        unloadEventEnd: u64,
        redirectStart: u64,
        redirectEnd: u64,
        fetchStart: u64,
        domainLookupStart: u64,
        domainLookupEnd: u64,
        connectStart: u64,
        connectEnd: u64,
        secureConnectionStart: u64,
        requestStart: u64,
        responseStart: u64,
        responseEnd: u64,
        domLoading: u64,
        domInteractive: u64,
        domContentLoadedEventStart: u64,
        domContentLoadedEventEnd: u64,
        domComplete: u64,
        loadEventStart: u64,
        loadEventEnd: u64,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_connectEnd = &get_connectEnd,
        .get_connectStart = &get_connectStart,
        .get_domComplete = &get_domComplete,
        .get_domContentLoadedEventEnd = &get_domContentLoadedEventEnd,
        .get_domContentLoadedEventStart = &get_domContentLoadedEventStart,
        .get_domInteractive = &get_domInteractive,
        .get_domLoading = &get_domLoading,
        .get_domainLookupEnd = &get_domainLookupEnd,
        .get_domainLookupStart = &get_domainLookupStart,
        .get_fetchStart = &get_fetchStart,
        .get_loadEventEnd = &get_loadEventEnd,
        .get_loadEventStart = &get_loadEventStart,
        .get_navigationStart = &get_navigationStart,
        .get_redirectEnd = &get_redirectEnd,
        .get_redirectStart = &get_redirectStart,
        .get_requestStart = &get_requestStart,
        .get_responseEnd = &get_responseEnd,
        .get_responseStart = &get_responseStart,
        .get_secureConnectionStart = &get_secureConnectionStart,
        .get_unloadEventEnd = &get_unloadEventEnd,
        .get_unloadEventStart = &get_unloadEventStart,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("PerformanceTiming has no construction argument '" ++ field_name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(PerformanceTimingImpl, "init") and @hasDecl(PerformanceTimingImpl, "initOwn")) @compileError("PerformanceTimingImpl defines both init and initOwn");
        if (comptime @hasDecl(PerformanceTimingImpl, "init")) return PerformanceTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PerformanceTimingImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PerformanceTimingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PerformanceTimingImpl, "init")) return false;
        if (comptime @hasDecl(PerformanceTimingImpl, "construction_args")) {
            inline for (PerformanceTimingImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(PerformanceTimingImpl, "deinit") and @hasDecl(PerformanceTimingImpl, "deinitOwn")) @compileError("PerformanceTimingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PerformanceTimingImpl, "deinit")) return PerformanceTimingImpl.deinit(instance);
        if (comptime @hasDecl(PerformanceTimingImpl, "deinitOwn")) PerformanceTimingImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PerformanceTiming")) {
            if (comptime @hasDecl(impls.PerformanceTiming, "installHooks")) impls.PerformanceTiming.installHooks();
        }
    }

    pub fn get_navigationStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_navigationStart(instance);
    }

    pub fn get_unloadEventStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_unloadEventStart(instance);
    }

    pub fn get_unloadEventEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_unloadEventEnd(instance);
    }

    pub fn get_redirectStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_redirectStart(instance);
    }

    pub fn get_redirectEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_redirectEnd(instance);
    }

    pub fn get_fetchStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_fetchStart(instance);
    }

    pub fn get_domainLookupStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domainLookupStart(instance);
    }

    pub fn get_domainLookupEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domainLookupEnd(instance);
    }

    pub fn get_connectStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_connectStart(instance);
    }

    pub fn get_connectEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_connectEnd(instance);
    }

    pub fn get_secureConnectionStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_secureConnectionStart(instance);
    }

    pub fn get_requestStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_requestStart(instance);
    }

    pub fn get_responseStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_responseStart(instance);
    }

    pub fn get_responseEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_responseEnd(instance);
    }

    pub fn get_domLoading(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domLoading(instance);
    }

    pub fn get_domInteractive(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domInteractive(instance);
    }

    pub fn get_domContentLoadedEventStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domContentLoadedEventStart(instance);
    }

    pub fn get_domContentLoadedEventEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domContentLoadedEventEnd(instance);
    }

    pub fn get_domComplete(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domComplete(instance);
    }

    pub fn get_loadEventStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_loadEventStart(instance);
    }

    pub fn get_loadEventEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_loadEventEnd(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceTimingToJSON {
        return try PerformanceTimingImpl.call_toJSON(instance);
    }
};
