//! Generated from: geolocation.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GeolocationImpl = @import("impls").Geolocation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PositionCallback = @import("callbacks").PositionCallback;
const PositionErrorCallback = @import("callbacks").PositionErrorCallback;
const PositionOptions = @import("dictionaries").PositionOptions;

pub const Geolocation = struct {
    pub const Meta = struct {
        pub const name = "Geolocation";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getCurrentPosition", "call_getCurrentPosition", 1 },
            .{ "watchPosition", "call_watchPosition", 1 },
            .{ "clearWatch", "call_clearWatch", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCurrentPosition",
            "watchPosition",
            "clearWatch",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*GeolocationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_clearWatch = &call_clearWatch,
        .call_getCurrentPosition = &call_getCurrentPosition,
        .call_watchPosition = &call_watchPosition,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Geolocation has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GeolocationImpl, "init") and @hasDecl(GeolocationImpl, "initOwn")) @compileError("GeolocationImpl defines both init and initOwn");
        if (comptime @hasDecl(GeolocationImpl, "init")) return GeolocationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GeolocationImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GeolocationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GeolocationImpl, "init")) return false;
        if (comptime @hasDecl(GeolocationImpl, "construction_args")) {
            inline for (GeolocationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GeolocationImpl, "deinit") and @hasDecl(GeolocationImpl, "deinitOwn")) @compileError("GeolocationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GeolocationImpl, "deinit")) return GeolocationImpl.deinit(instance);
        if (comptime @hasDecl(GeolocationImpl, "deinitOwn")) GeolocationImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Geolocation")) {
            if (comptime @hasDecl(impls.Geolocation, "installHooks")) impls.Geolocation.installHooks();
        }
    }

    pub fn call_getCurrentPosition(instance: *runtime.Instance, successCallback: PositionCallback, errorCallback: webidl.Opt(?PositionErrorCallback), options: webidl.Opt(PositionOptions)) anyerror!void {
        return try GeolocationImpl.call_getCurrentPosition(instance, successCallback, errorCallback, options);
    }

    pub fn call_watchPosition(instance: *runtime.Instance, successCallback: PositionCallback, errorCallback: webidl.Opt(?PositionErrorCallback), options: webidl.Opt(PositionOptions)) anyerror!i32 {
        return try GeolocationImpl.call_watchPosition(instance, successCallback, errorCallback, options);
    }

    pub fn call_clearWatch(instance: *runtime.Instance, watchId: i32) anyerror!void {
        return try GeolocationImpl.call_clearWatch(instance, watchId);
    }
};
