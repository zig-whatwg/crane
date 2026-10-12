//! Generated from: compute-pressure.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PressureObserverImpl = @import("impls").PressureObserver;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PressureSource = @import("enums").PressureSource;
const PressureRecord = @import("interfaces").PressureRecord;
const PressureObserverOptions = @import("dictionaries").PressureObserverOptions;
const PressureUpdateCallback = @import("callbacks").PressureUpdateCallback;

pub const PressureObserver = struct {
    pub const Meta = struct {
        pub const name = "PressureObserver";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "observe", "call_observe", 1 },
            .{ "unobserve", "call_unobserve", 1 },
            .{ "disconnect", "call_disconnect", 0 },
            .{ "takeRecords", "call_takeRecords", 0 },
        };

        /// Static attribute binding hints for V8Interface (JS name, getter fn name, setter fn name or null)
        pub const static_properties = .{
            .{ "knownSources", "get_static_knownSources", null },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "observe",
            "unobserve",
            "disconnect",
            "takeRecords",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*PressureObserverImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
        .call_unobserve = &call_unobserve,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("PressureObserver has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PressureObserverImpl, "init") and @hasDecl(PressureObserverImpl, "initOwn")) @compileError("PressureObserverImpl defines both init and initOwn");
        if (comptime @hasDecl(PressureObserverImpl, "init")) return PressureObserverImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PressureObserverImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PressureObserverImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PressureObserverImpl, "init")) return false;
        if (comptime @hasDecl(PressureObserverImpl, "construction_args")) {
            inline for (PressureObserverImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PressureObserverImpl, "deinit") and @hasDecl(PressureObserverImpl, "deinitOwn")) @compileError("PressureObserverImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PressureObserverImpl, "deinit")) return PressureObserverImpl.deinit(instance);
        if (comptime @hasDecl(PressureObserverImpl, "deinitOwn")) PressureObserverImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PressureObserver")) {
            if (comptime @hasDecl(impls.PressureObserver, "installHooks")) impls.PressureObserver.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, callback: PressureUpdateCallback) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PressureObserverImpl.call_constructor(ctx, callback);
    }

    /// Extended attributes: [SameObject]
    pub fn get_static_knownSources(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PressureObserverImpl.get_static_knownSources(instance);
    }

    pub fn call_unobserve(instance: *runtime.Instance, source: PressureSource) anyerror!void {
        return try PressureObserverImpl.call_unobserve(instance, source);
    }

    pub fn call_observe(instance: *runtime.Instance, source: PressureSource, options: webidl.Opt(PressureObserverOptions)) anyerror!runtime.JSValue {
        return try PressureObserverImpl.call_observe(instance, source, options);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try PressureObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PressureObserverImpl.call_takeRecords(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_observe",
    };
};
