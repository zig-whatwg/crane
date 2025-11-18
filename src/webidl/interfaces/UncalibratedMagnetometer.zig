//! Generated from: magnetometer.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const UncalibratedMagnetometerImpl = @import("impls").UncalibratedMagnetometer;
const Sensor = @import("interfaces").Sensor;
const MagnetometerSensorOptions = @import("dictionaries").MagnetometerSensorOptions;
const double = @import("interfaces").double;

pub const UncalibratedMagnetometer = struct {
    pub const Meta = struct {
        pub const name = "UncalibratedMagnetometer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Sensor;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            x: ?f64 = null,
            y: ?f64 = null,
            z: ?f64 = null,
            xBias: ?f64 = null,
            yBias: ?f64 = null,
            zBias: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(UncalibratedMagnetometer, .{
        .deinit_fn = &deinit_wrapper,

        .get_activated = &get_activated,
        .get_hasReading = &get_hasReading,
        .get_onactivate = &get_onactivate,
        .get_onerror = &get_onerror,
        .get_onreading = &get_onreading,
        .get_timestamp = &get_timestamp,
        .get_x = &get_x,
        .get_xBias = &get_xBias,
        .get_y = &get_y,
        .get_yBias = &get_yBias,
        .get_z = &get_z,
        .get_zBias = &get_zBias,

        .set_onactivate = &set_onactivate,
        .set_onerror = &set_onerror,
        .set_onreading = &set_onreading,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
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
        UncalibratedMagnetometerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        UncalibratedMagnetometerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, sensorOptions: MagnetometerSensorOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try UncalibratedMagnetometerImpl.constructor(instance, sensorOptions);
        
        return instance;
    }

    pub fn get_activated(instance: *runtime.Instance) anyerror!bool {
        return try UncalibratedMagnetometerImpl.get_activated(instance);
    }

    pub fn get_hasReading(instance: *runtime.Instance) anyerror!bool {
        return try UncalibratedMagnetometerImpl.get_hasReading(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!anyopaque {
        return try UncalibratedMagnetometerImpl.get_timestamp(instance);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try UncalibratedMagnetometerImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try UncalibratedMagnetometerImpl.set_onreading(instance, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try UncalibratedMagnetometerImpl.get_onactivate(instance);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try UncalibratedMagnetometerImpl.set_onactivate(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try UncalibratedMagnetometerImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try UncalibratedMagnetometerImpl.set_onerror(instance, value);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!anyopaque {
        return try UncalibratedMagnetometerImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!anyopaque {
        return try UncalibratedMagnetometerImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!anyopaque {
        return try UncalibratedMagnetometerImpl.get_z(instance);
    }

    pub fn get_xBias(instance: *runtime.Instance) anyerror!anyopaque {
        return try UncalibratedMagnetometerImpl.get_xBias(instance);
    }

    pub fn get_yBias(instance: *runtime.Instance) anyerror!anyopaque {
        return try UncalibratedMagnetometerImpl.get_yBias(instance);
    }

    pub fn get_zBias(instance: *runtime.Instance) anyerror!anyopaque {
        return try UncalibratedMagnetometerImpl.get_zBias(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try UncalibratedMagnetometerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try UncalibratedMagnetometerImpl.call_stop(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try UncalibratedMagnetometerImpl.call_when(instance, type_, options);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try UncalibratedMagnetometerImpl.call_start(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try UncalibratedMagnetometerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try UncalibratedMagnetometerImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
