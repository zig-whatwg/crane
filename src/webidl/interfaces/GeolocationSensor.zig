//! Generated from: geolocation-sensor.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationSensorImpl = @import("impls").GeolocationSensor;
const Sensor = @import("interfaces").Sensor;
const unrestricted double = @import("interfaces").unrestricted double;
const Promise<GeolocationSensorReading> = @import("interfaces").Promise<GeolocationSensorReading>;
const ReadOptions = @import("dictionaries").ReadOptions;
const GeolocationSensorOptions = @import("dictionaries").GeolocationSensorOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        GeolocationSensorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationSensorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: GeolocationSensorOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try GeolocationSensorImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_activated(instance: *runtime.Instance) anyerror!bool {
        return try GeolocationSensorImpl.get_activated(instance);
    }

    pub fn get_hasReading(instance: *runtime.Instance) anyerror!bool {
        return try GeolocationSensorImpl.get_hasReading(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_timestamp(instance);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try GeolocationSensorImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try GeolocationSensorImpl.set_onreading(instance, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try GeolocationSensorImpl.get_onactivate(instance);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try GeolocationSensorImpl.set_onactivate(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try GeolocationSensorImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try GeolocationSensorImpl.set_onerror(instance, value);
    }

    pub fn get_latitude(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_latitude(instance);
    }

    pub fn get_longitude(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_longitude(instance);
    }

    pub fn get_altitude(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_altitude(instance);
    }

    pub fn get_accuracy(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_accuracy(instance);
    }

    pub fn get_altitudeAccuracy(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_altitudeAccuracy(instance);
    }

    pub fn get_heading(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_heading(instance);
    }

    pub fn get_speed(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationSensorImpl.get_speed(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try GeolocationSensorImpl.call_stop(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try GeolocationSensorImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try GeolocationSensorImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_read(instance: *runtime.Instance, readOptions: ReadOptions) anyerror!anyopaque {
        
        return try GeolocationSensorImpl.call_read(instance, readOptions);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try GeolocationSensorImpl.call_start(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try GeolocationSensorImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try GeolocationSensorImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
