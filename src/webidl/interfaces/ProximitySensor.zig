//! Generated from: proximity.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ProximitySensorImpl = @import("impls").ProximitySensor;
const Sensor = @import("interfaces").Sensor;
const boolean = @import("interfaces").boolean;
const double = @import("interfaces").double;
const SensorOptions = @import("dictionaries").SensorOptions;

pub const ProximitySensor = struct {
    pub const Meta = struct {
        pub const name = "ProximitySensor";
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
            distance: ?f64 = null,
            max: ?f64 = null,
            near: ?bool = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ProximitySensor, .{
        .deinit_fn = &deinit_wrapper,

        .get_activated = &get_activated,
        .get_distance = &get_distance,
        .get_hasReading = &get_hasReading,
        .get_max = &get_max,
        .get_near = &get_near,
        .get_onactivate = &get_onactivate,
        .get_onerror = &get_onerror,
        .get_onreading = &get_onreading,
        .get_timestamp = &get_timestamp,

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
        ProximitySensorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProximitySensorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, sensorOptions: SensorOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ProximitySensorImpl.constructor(instance, sensorOptions);
        
        return instance;
    }

    pub fn get_activated(instance: *runtime.Instance) anyerror!bool {
        return try ProximitySensorImpl.get_activated(instance);
    }

    pub fn get_hasReading(instance: *runtime.Instance) anyerror!bool {
        return try ProximitySensorImpl.get_hasReading(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!anyopaque {
        return try ProximitySensorImpl.get_timestamp(instance);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try ProximitySensorImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ProximitySensorImpl.set_onreading(instance, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try ProximitySensorImpl.get_onactivate(instance);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ProximitySensorImpl.set_onactivate(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try ProximitySensorImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ProximitySensorImpl.set_onerror(instance, value);
    }

    pub fn get_distance(instance: *runtime.Instance) anyerror!anyopaque {
        return try ProximitySensorImpl.get_distance(instance);
    }

    pub fn get_max(instance: *runtime.Instance) anyerror!anyopaque {
        return try ProximitySensorImpl.get_max(instance);
    }

    pub fn get_near(instance: *runtime.Instance) anyerror!anyopaque {
        return try ProximitySensorImpl.get_near(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ProximitySensorImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try ProximitySensorImpl.call_stop(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ProximitySensorImpl.call_when(instance, type_, options);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try ProximitySensorImpl.call_start(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ProximitySensorImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ProximitySensorImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
