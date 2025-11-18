//! Generated from: orientation-event.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeviceMotionEventImpl = @import("impls").DeviceMotionEvent;
const Event = @import("interfaces").Event;
const DeviceMotionEventInit = @import("dictionaries").DeviceMotionEventInit;
const DeviceMotionEventAcceleration = @import("interfaces").DeviceMotionEventAcceleration;
const Promise<PermissionState> = @import("interfaces").Promise<PermissionState>;
const DeviceMotionEventRotationRate = @import("interfaces").DeviceMotionEventRotationRate;

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
        
        // Initialize the instance (Impl receives full instance)
        DeviceMotionEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DeviceMotionEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: DeviceMotionEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DeviceMotionEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try DeviceMotionEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try DeviceMotionEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try DeviceMotionEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try DeviceMotionEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try DeviceMotionEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try DeviceMotionEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try DeviceMotionEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try DeviceMotionEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try DeviceMotionEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try DeviceMotionEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try DeviceMotionEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try DeviceMotionEventImpl.get_timeStamp(instance);
    }

    pub fn get_acceleration(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.get_acceleration(instance);
    }

    pub fn get_accelerationIncludingGravity(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.get_accelerationIncludingGravity(instance);
    }

    pub fn get_rotationRate(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.get_rotationRate(instance);
    }

    pub fn get_interval(instance: *runtime.Instance) anyerror!f64 {
        return try DeviceMotionEventImpl.get_interval(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try DeviceMotionEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try DeviceMotionEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_requestPermission(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.call_requestPermission(instance);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try DeviceMotionEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try DeviceMotionEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try DeviceMotionEventImpl.call_preventDefault(instance);
    }

};
