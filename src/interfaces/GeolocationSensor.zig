//! Generated from: geolocation-sensor.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationSensorImpl = @import("../impls/GeolocationSensor.zig");
const Sensor = @import("Sensor.zig");

pub const GeolocationSensor = struct {
    pub const Meta = struct {
        pub const name = "GeolocationSensor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Sensor;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            latitude: ?f64 = null,
            longitude: ?f64 = null,
            altitude: ?f64 = null,
            accuracy: ?f64 = null,
            altitudeAccuracy: ?f64 = null,
            heading: ?f64 = null,
            speed: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GeolocationSensor, .{
        .deinit_fn = &deinit_wrapper,

        .get_accuracy = &get_accuracy,
        .get_activated = &get_activated,
        .get_altitude = &get_altitude,
        .get_altitudeAccuracy = &get_altitudeAccuracy,
        .get_hasReading = &get_hasReading,
        .get_heading = &get_heading,
        .get_latitude = &get_latitude,
        .get_longitude = &get_longitude,
        .get_onactivate = &get_onactivate,
        .get_onerror = &get_onerror,
        .get_onreading = &get_onreading,
        .get_speed = &get_speed,
        .get_timestamp = &get_timestamp,

        .set_onactivate = &set_onactivate,
        .set_onerror = &set_onerror,
        .set_onreading = &set_onreading,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_read = &call_read,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
        .call_stop = &call_stop,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GeolocationSensorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GeolocationSensorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try GeolocationSensorImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_activated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_activated(state);
    }

    pub fn get_hasReading(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_hasReading(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_timestamp(state);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_onreading(state);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        GeolocationSensorImpl.set_onreading(state, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_onactivate(state);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        GeolocationSensorImpl.set_onactivate(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        GeolocationSensorImpl.set_onerror(state, value);
    }

    pub fn get_latitude(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_latitude(state);
    }

    pub fn get_longitude(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_longitude(state);
    }

    pub fn get_altitude(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_altitude(state);
    }

    pub fn get_accuracy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_accuracy(state);
    }

    pub fn get_altitudeAccuracy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_altitudeAccuracy(state);
    }

    pub fn get_heading(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_heading(state);
    }

    pub fn get_speed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.get_speed(state);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.call_stop(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GeolocationSensorImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return GeolocationSensorImpl.call_dispatchEvent(state, event);
    }

    pub fn call_read(instance: *runtime.Instance, readOptions: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GeolocationSensorImpl.call_read(state, readOptions);
    }

    pub fn call_start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationSensorImpl.call_start(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GeolocationSensorImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GeolocationSensorImpl.call_removeEventListener(state, type_, callback, options);
    }

};
