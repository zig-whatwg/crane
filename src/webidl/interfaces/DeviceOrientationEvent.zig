//! Generated from: orientation-event.idl
//! Generated at: 2025-11-25T14:21:39Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeviceOrientationEventImpl = @import("impls").DeviceOrientationEvent;
const Event = @import("interfaces").Event;
const PermissionState = @import("enums").PermissionState;
const DeviceOrientationEventInit = @import("dictionaries").DeviceOrientationEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const DeviceOrientationEvent = struct {
    pub const Meta = struct {
        pub const name = "DeviceOrientationEvent";
        pub const is_mixin = false;
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
            .{ "alpha", "get_alpha", null },
            .{ "beta", "get_beta", null },
            .{ "gamma", "get_gamma", null },
            .{ "absolute", "get_absolute", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
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
            .{ "alpha", "get_alpha", null },
            .{ "beta", "get_beta", null },
            .{ "gamma", "get_gamma", null },
            .{ "absolute", "get_absolute", null },
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
            alpha: ?f64 = null,
            beta: ?f64 = null,
            gamma: ?f64 = null,
            absolute: bool = undefined,
            _internal: ?*DeviceOrientationEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_absolute = &get_absolute,
        .get_alpha = &get_alpha,
        .get_beta = &get_beta,
        .get_gamma = &get_gamma,

        .call_requestPermission = &call_requestPermission,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DeviceOrientationEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DeviceOrientationEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: DeviceOrientationEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DeviceOrientationEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceOrientationEventImpl.get_alpha(instance);
    }

    pub fn get_beta(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceOrientationEventImpl.get_beta(instance);
    }

    pub fn get_gamma(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceOrientationEventImpl.get_gamma(instance);
    }

    pub fn get_absolute(instance: *runtime.Instance) anyerror!bool {
        return try DeviceOrientationEventImpl.get_absolute(instance);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, absolute: bool) anyerror!*const anyopaque {
        
        return try DeviceOrientationEventImpl.call_requestPermission(instance, absolute);
    }

};
