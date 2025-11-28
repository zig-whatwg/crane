//! Generated from: geolocation.idl
//! Generated at: 2025-11-28T18:02:26Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationCoordinatesImpl = @import("impls").GeolocationCoordinates;

pub const GeolocationCoordinates = struct {
    pub const Meta = struct {
        pub const name = "GeolocationCoordinates";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        pub const inherited_methods = .{
        };
        
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
        pub const lazy_properties = .{
        };
        
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

    const delegates = .{

        .get_accuracy = &get_accuracy,
        .get_altitude = &get_altitude,
        .get_altitudeAccuracy = &get_altitudeAccuracy,
        .get_heading = &get_heading,
        .get_latitude = &get_latitude,
        .get_longitude = &get_longitude,
        .get_speed = &get_speed,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GeolocationCoordinatesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationCoordinatesImpl.deinit(instance);
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
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GeolocationCoordinatesImpl.call_toJSON(instance);
    }

};
