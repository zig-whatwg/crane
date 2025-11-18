//! Generated from: geolocation.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationCoordinatesImpl = @import("../impls/GeolocationCoordinates.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GeolocationCoordinatesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GeolocationCoordinatesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_accuracy(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.get_accuracy(state);
    }

    pub fn get_latitude(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.get_latitude(state);
    }

    pub fn get_longitude(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.get_longitude(state);
    }

    pub fn get_altitude(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.get_altitude(state);
    }

    pub fn get_altitudeAccuracy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.get_altitudeAccuracy(state);
    }

    pub fn get_heading(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.get_heading(state);
    }

    pub fn get_speed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.get_speed(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationCoordinatesImpl.call_toJSON(state);
    }

};
