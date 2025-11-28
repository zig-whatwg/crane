//! Generated from: orientation-event.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DeviceMotionEventImpl = @import("impls").DeviceMotionEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const PermissionState = @import("enums").PermissionState;
const DeviceMotionEventRotationRate = @import("interfaces").DeviceMotionEventRotationRate;
const DeviceMotionEventInit = @import("dictionaries").DeviceMotionEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DeviceMotionEventAcceleration = @import("interfaces").DeviceMotionEventAcceleration;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const DeviceMotionEvent = struct {
    pub const Meta = struct {
        pub const name = "DeviceMotionEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "acceleration", "get_acceleration", null },
            .{ "accelerationIncludingGravity", "get_accelerationIncludingGravity", null },
            .{ "rotationRate", "get_rotationRate", null },
            .{ "interval", "get_interval", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "requestPermission", "call_requestPermission", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPermission",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "acceleration", "get_acceleration", null },
            .{ "accelerationIncludingGravity", "get_accelerationIncludingGravity", null },
            .{ "rotationRate", "get_rotationRate", null },
            .{ "interval", "get_interval", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            acceleration: ?*runtime.Instance = null,
            accelerationIncludingGravity: ?*runtime.Instance = null,
            rotationRate: ?*runtime.Instance = null,
            interval: f64 = undefined,
            _internal: ?*DeviceMotionEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_acceleration = &get_acceleration,
        .get_accelerationIncludingGravity = &get_accelerationIncludingGravity,
        .get_interval = &get_interval,
        .get_rotationRate = &get_rotationRate,

        .call_requestPermission = &call_requestPermission,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DeviceMotionEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DeviceMotionEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(DeviceMotionEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DeviceMotionEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_acceleration(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DeviceMotionEventImpl.get_acceleration(instance);
    }

    pub fn get_accelerationIncludingGravity(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DeviceMotionEventImpl.get_accelerationIncludingGravity(instance);
    }

    pub fn get_rotationRate(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DeviceMotionEventImpl.get_rotationRate(instance);
    }

    pub fn get_interval(instance: *runtime.Instance) anyerror!f64 {
        return try DeviceMotionEventImpl.get_interval(instance);
    }

    pub fn call_requestPermission(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DeviceMotionEventImpl.call_requestPermission(instance);
    }

};
