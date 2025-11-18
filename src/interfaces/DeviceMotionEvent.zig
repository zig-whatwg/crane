//! Generated from: orientation-event.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeviceMotionEventImpl = @import("../impls/DeviceMotionEvent.zig");
const Event = @import("Event.zig");

pub const DeviceMotionEvent = struct {
    pub const Meta = struct {
        pub const name = "DeviceMotionEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            acceleration: ?DeviceMotionEventAcceleration = null,
            accelerationIncludingGravity: ?DeviceMotionEventAcceleration = null,
            rotationRate: ?DeviceMotionEventRotationRate = null,
            interval: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DeviceMotionEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &Event.get_AT_TARGET,
        .get_BUBBLING_PHASE = &Event.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &Event.get_CAPTURING_PHASE,
        .get_NONE = &Event.get_NONE,
        .get_acceleration = &get_acceleration,
        .get_accelerationIncludingGravity = &get_accelerationIncludingGravity,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_interval = &get_interval,
        .get_isTrusted = &get_isTrusted,
        .get_returnValue = &get_returnValue,
        .get_rotationRate = &get_rotationRate,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_preventDefault = &call_preventDefault,
        .call_requestPermission = &call_requestPermission,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DeviceMotionEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DeviceMotionEventImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: runtime.DOMString, eventInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try DeviceMotionEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        DeviceMotionEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        DeviceMotionEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_timeStamp(state);
    }

    pub fn get_acceleration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_acceleration(state);
    }

    pub fn get_accelerationIncludingGravity(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_accelerationIncludingGravity(state);
    }

    pub fn get_rotationRate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_rotationRate(state);
    }

    pub fn get_interval(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.get_interval(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return DeviceMotionEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_requestPermission(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.call_requestPermission(state);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventImpl.call_preventDefault(state);
    }

};
