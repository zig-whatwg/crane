//! Generated from: geolocation.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GeolocationCoordinatesImpl = @import("impls").GeolocationCoordinates;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const GeolocationCoordinates = struct {
    pub const Meta = struct {
        pub const name = "GeolocationCoordinates";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "accuracy", "get_accuracy", null },
            .{ "latitude", "get_latitude", null },
            .{ "longitude", "get_longitude", null },
            .{ "altitude", "get_altitude", null },
            .{ "altitudeAccuracy", "get_altitudeAccuracy", null },
            .{ "heading", "get_heading", null },
            .{ "speed", "get_speed", null },
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
            .{ "accuracy", "get_accuracy", null },
            .{ "latitude", "get_latitude", null },
            .{ "longitude", "get_longitude", null },
            .{ "altitude", "get_altitude", null },
            .{ "altitudeAccuracy", "get_altitudeAccuracy", null },
            .{ "heading", "get_heading", null },
            .{ "speed", "get_speed", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            accuracy: f64 = undefined,
            latitude: f64 = undefined,
            longitude: f64 = undefined,
            altitude: ?f64 = null,
            altitudeAccuracy: ?f64 = null,
            heading: ?f64 = null,
            speed: ?f64 = null,
            _internal: ?*GeolocationCoordinatesImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for GeolocationCoordinates
    /// Generated from [Default] toJSON extended attribute
    pub const GeolocationCoordinatesToJSON = struct {
        accuracy: f64,
        latitude: f64,
        longitude: f64,
        altitude: ?f64,
        altitudeAccuracy: ?f64,
        heading: ?f64,
        speed: ?f64,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_accuracy = &get_accuracy,
        .get_altitude = &get_altitude,
        .get_altitudeAccuracy = &get_altitudeAccuracy,
        .get_heading = &get_heading,
        .get_latitude = &get_latitude,
        .get_longitude = &get_longitude,
        .get_speed = &get_speed,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("GeolocationCoordinates has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "init") and @hasDecl(GeolocationCoordinatesImpl, "initOwn")) @compileError("GeolocationCoordinatesImpl defines both init and initOwn");
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "init")) return GeolocationCoordinatesImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GeolocationCoordinatesImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "init")) return false;
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "construction_args")) {
            inline for (GeolocationCoordinatesImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "deinit") and @hasDecl(GeolocationCoordinatesImpl, "deinitOwn")) @compileError("GeolocationCoordinatesImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "deinit")) return GeolocationCoordinatesImpl.deinit(instance);
        if (comptime @hasDecl(GeolocationCoordinatesImpl, "deinitOwn")) GeolocationCoordinatesImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GeolocationCoordinates")) {
            if (comptime @hasDecl(impls.GeolocationCoordinates, "installHooks")) impls.GeolocationCoordinates.installHooks();
        }
    }

    pub fn get_accuracy(instance: *runtime.Instance) anyerror!f64 {
        return try GeolocationCoordinatesImpl.get_accuracy(instance);
    }

    pub fn get_latitude(instance: *runtime.Instance) anyerror!f64 {
        return try GeolocationCoordinatesImpl.get_latitude(instance);
    }

    pub fn get_longitude(instance: *runtime.Instance) anyerror!f64 {
        return try GeolocationCoordinatesImpl.get_longitude(instance);
    }

    pub fn get_altitude(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationCoordinatesImpl.get_altitude(instance);
    }

    pub fn get_altitudeAccuracy(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationCoordinatesImpl.get_altitudeAccuracy(instance);
    }

    pub fn get_heading(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationCoordinatesImpl.get_heading(instance);
    }

    pub fn get_speed(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationCoordinatesImpl.get_speed(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!GeolocationCoordinatesToJSON {
        return try GeolocationCoordinatesImpl.call_toJSON(instance);
    }
};
