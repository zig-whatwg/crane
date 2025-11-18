//! Generated from: accelerometer.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AccelerometerImpl = @import("../impls/Accelerometer.zig");
const Sensor = @import("Sensor.zig");

pub const Accelerometer = struct {
    pub const Meta = struct {
        pub const name = "Accelerometer";
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Accelerometer, .{
        .deinit_fn = &deinit_wrapper,

        .get_activated = &get_activated,
        .get_hasReading = &get_hasReading,
        .get_onactivate = &get_onactivate,
        .get_onerror = &get_onerror,
        .get_onreading = &get_onreading,
        .get_timestamp = &get_timestamp,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

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
        
        // Initialize the state (Impl receives full hierarchy)
        AccelerometerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AccelerometerImpl.deinit(state);
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
        try AccelerometerImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_activated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AccelerometerImpl.get_activated(state);
    }

    pub fn get_hasReading(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AccelerometerImpl.get_hasReading(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.get_timestamp(state);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.get_onreading(state);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AccelerometerImpl.set_onreading(state, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.get_onactivate(state);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AccelerometerImpl.set_onactivate(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AccelerometerImpl.set_onerror(state, value);
    }

    pub fn get_x(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.get_x(state);
    }

    pub fn get_y(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.get_y(state);
    }

    pub fn get_z(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.get_z(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return AccelerometerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.call_stop(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AccelerometerImpl.call_when(state, type_, options);
    }

    pub fn call_start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AccelerometerImpl.call_start(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AccelerometerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AccelerometerImpl.call_removeEventListener(state, type_, callback, options);
    }

};
