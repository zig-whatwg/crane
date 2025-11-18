//! Generated from: orientation-sensor.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RelativeOrientationSensorImpl = @import("impls").RelativeOrientationSensor;
const OrientationSensor = @import("interfaces").OrientationSensor;
const OrientationSensorOptions = @import("dictionaries").OrientationSensorOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        RelativeOrientationSensorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RelativeOrientationSensorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, sensorOptions: OrientationSensorOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RelativeOrientationSensorImpl.constructor(instance, sensorOptions);
        
        return instance;
    }

    pub fn get_activated(instance: *runtime.Instance) anyerror!bool {
        return try RelativeOrientationSensorImpl.get_activated(instance);
    }

    pub fn get_hasReading(instance: *runtime.Instance) anyerror!bool {
        return try RelativeOrientationSensorImpl.get_hasReading(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!anyopaque {
        return try RelativeOrientationSensorImpl.get_timestamp(instance);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try RelativeOrientationSensorImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RelativeOrientationSensorImpl.set_onreading(instance, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try RelativeOrientationSensorImpl.get_onactivate(instance);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RelativeOrientationSensorImpl.set_onactivate(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try RelativeOrientationSensorImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RelativeOrientationSensorImpl.set_onerror(instance, value);
    }

    pub fn get_quaternion(instance: *runtime.Instance) anyerror!anyopaque {
        return try RelativeOrientationSensorImpl.get_quaternion(instance);
    }

    pub fn call_populateMatrix(instance: *runtime.Instance, targetMatrix: RotationMatrixType) anyerror!void {
        
        return try RelativeOrientationSensorImpl.call_populateMatrix(instance, targetMatrix);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try RelativeOrientationSensorImpl.call_stop(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RelativeOrientationSensorImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RelativeOrientationSensorImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try RelativeOrientationSensorImpl.call_start(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RelativeOrientationSensorImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RelativeOrientationSensorImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
