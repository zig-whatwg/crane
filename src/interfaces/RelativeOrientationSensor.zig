//! Generated from: orientation-sensor.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RelativeOrientationSensorImpl = @import("../impls/RelativeOrientationSensor.zig");
const OrientationSensor = @import("OrientationSensor.zig");

pub const RelativeOrientationSensor = struct {
    pub const Meta = struct {
        pub const name = "RelativeOrientationSensor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *OrientationSensor;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RelativeOrientationSensor, .{
        .deinit_fn = &deinit_wrapper,

        .get_activated = &get_activated,
        .get_hasReading = &get_hasReading,
        .get_onactivate = &get_onactivate,
        .get_onerror = &get_onerror,
        .get_onreading = &get_onreading,
        .get_quaternion = &get_quaternion,
        .get_timestamp = &get_timestamp,

        .set_onactivate = &set_onactivate,
        .set_onerror = &set_onerror,
        .set_onreading = &set_onreading,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_populateMatrix = &call_populateMatrix,
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
        RelativeOrientationSensorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RelativeOrientationSensorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, sensorOptions: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RelativeOrientationSensorImpl.constructor(state, sensorOptions);
        
        return instance;
    }

    pub fn get_activated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.get_activated(state);
    }

    pub fn get_hasReading(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.get_hasReading(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.get_timestamp(state);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.get_onreading(state);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RelativeOrientationSensorImpl.set_onreading(state, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.get_onactivate(state);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RelativeOrientationSensorImpl.set_onactivate(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RelativeOrientationSensorImpl.set_onerror(state, value);
    }

    pub fn get_quaternion(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.get_quaternion(state);
    }

    pub fn call_populateMatrix(instance: *runtime.Instance, targetMatrix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RelativeOrientationSensorImpl.call_populateMatrix(state, targetMatrix);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.call_stop(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RelativeOrientationSensorImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RelativeOrientationSensorImpl.call_dispatchEvent(state, event);
    }

    pub fn call_start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RelativeOrientationSensorImpl.call_start(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RelativeOrientationSensorImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RelativeOrientationSensorImpl.call_removeEventListener(state, type_, callback, options);
    }

};
