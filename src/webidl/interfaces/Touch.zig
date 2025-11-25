//! Generated from: touch-events.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TouchImpl = @import("impls").Touch;
const TouchInit = @import("dictionaries").TouchInit;
const EventTarget = @import("interfaces").EventTarget;
const TouchType = @import("enums").TouchType;

pub const Touch = struct {
    pub const Meta = struct {
        pub const name = "Touch";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "identifier", "get_identifier", null },
            .{ "target", "get_target", null },
            .{ "screenX", "get_screenX", null },
            .{ "screenY", "get_screenY", null },
            .{ "clientX", "get_clientX", null },
            .{ "clientY", "get_clientY", null },
            .{ "pageX", "get_pageX", null },
            .{ "pageY", "get_pageY", null },
            .{ "radiusX", "get_radiusX", null },
            .{ "radiusY", "get_radiusY", null },
            .{ "rotationAngle", "get_rotationAngle", null },
            .{ "force", "get_force", null },
            .{ "altitudeAngle", "get_altitudeAngle", null },
            .{ "azimuthAngle", "get_azimuthAngle", null },
            .{ "touchType", "get_touchType", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "identifier", "get_identifier", null },
            .{ "target", "get_target", null },
            .{ "screenX", "get_screenX", null },
            .{ "screenY", "get_screenY", null },
            .{ "clientX", "get_clientX", null },
            .{ "clientY", "get_clientY", null },
            .{ "pageX", "get_pageX", null },
            .{ "pageY", "get_pageY", null },
            .{ "radiusX", "get_radiusX", null },
            .{ "radiusY", "get_radiusY", null },
            .{ "rotationAngle", "get_rotationAngle", null },
            .{ "force", "get_force", null },
            .{ "altitudeAngle", "get_altitudeAngle", null },
            .{ "azimuthAngle", "get_azimuthAngle", null },
            .{ "touchType", "get_touchType", null },
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
            identifier: i32 = undefined,
            target: *runtime.Instance = undefined,
            screenX: f64 = undefined,
            screenY: f64 = undefined,
            clientX: f64 = undefined,
            clientY: f64 = undefined,
            pageX: f64 = undefined,
            pageY: f64 = undefined,
            radiusX: f32 = undefined,
            radiusY: f32 = undefined,
            rotationAngle: f32 = undefined,
            force: f32 = undefined,
            altitudeAngle: f32 = undefined,
            azimuthAngle: f32 = undefined,
            touchType: TouchType = undefined,
            _internal: ?*TouchImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_altitudeAngle = &get_altitudeAngle,
        .get_azimuthAngle = &get_azimuthAngle,
        .get_clientX = &get_clientX,
        .get_clientY = &get_clientY,
        .get_force = &get_force,
        .get_identifier = &get_identifier,
        .get_pageX = &get_pageX,
        .get_pageY = &get_pageY,
        .get_radiusX = &get_radiusX,
        .get_radiusY = &get_radiusY,
        .get_rotationAngle = &get_rotationAngle,
        .get_screenX = &get_screenX,
        .get_screenY = &get_screenY,
        .get_target = &get_target,
        .get_touchType = &get_touchType,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TouchImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TouchImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, touchInitDict: TouchInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TouchImpl.call_constructor(allocator, ctx, touchInitDict);
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!i32 {
        return try TouchImpl.get_identifier(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchImpl.get_target(instance);
    }

    pub fn get_screenX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_screenX(instance);
    }

    pub fn get_screenY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_screenY(instance);
    }

    pub fn get_clientX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_clientX(instance);
    }

    pub fn get_clientY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_clientY(instance);
    }

    pub fn get_pageX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_pageX(instance);
    }

    pub fn get_pageY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_pageY(instance);
    }

    pub fn get_radiusX(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_radiusX(instance);
    }

    pub fn get_radiusY(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_radiusY(instance);
    }

    pub fn get_rotationAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_rotationAngle(instance);
    }

    pub fn get_force(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_force(instance);
    }

    pub fn get_altitudeAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_altitudeAngle(instance);
    }

    pub fn get_azimuthAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_azimuthAngle(instance);
    }

    pub fn get_touchType(instance: *runtime.Instance) anyerror!TouchType {
        return try TouchImpl.get_touchType(instance);
    }

};
