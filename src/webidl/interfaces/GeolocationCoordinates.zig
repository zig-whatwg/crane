//! Generated from: geolocation.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationCoordinatesImpl = @import("impls").GeolocationCoordinates;
const double = @import("interfaces").double;

pub const GeolocationCoordinates = struct {
    pub const Meta = struct {
        pub const name = "GeolocationCoordinates";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            accuracy: f64 = undefined,
            latitude: f64 = undefined,
            longitude: f64 = undefined,
            altitude: ?f64 = null,
            altitudeAccuracy: ?f64 = null,
            heading: ?f64 = null,
            speed: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GeolocationCoordinates, .{
        .deinit_fn = &deinit_wrapper,

        .get_accuracy = &get_accuracy,
        .get_altitude = &get_altitude,
        .get_altitudeAccuracy = &get_altitudeAccuracy,
        .get_heading = &get_heading,
        .get_latitude = &get_latitude,
        .get_longitude = &get_longitude,
        .get_speed = &get_speed,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GeolocationCoordinatesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationCoordinatesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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

    pub fn get_altitude(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationCoordinatesImpl.get_altitude(instance);
    }

    pub fn get_altitudeAccuracy(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationCoordinatesImpl.get_altitudeAccuracy(instance);
    }

    pub fn get_heading(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationCoordinatesImpl.get_heading(instance);
    }

    pub fn get_speed(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationCoordinatesImpl.get_speed(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationCoordinatesImpl.call_toJSON(instance);
    }

};
