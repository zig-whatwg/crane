//! Generated from: webaudio.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioListenerImpl = @import("impls").AudioListener;
const AudioParam = @import("interfaces").AudioParam;

pub const AudioListener = struct {
    pub const Meta = struct {
        pub const name = "AudioListener";
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
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "forwardX", "get_forwardX", null },
            .{ "forwardY", "get_forwardY", null },
            .{ "forwardZ", "get_forwardZ", null },
            .{ "upX", "get_upX", null },
            .{ "upY", "get_upY", null },
            .{ "upZ", "get_upZ", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPosition", "call_setPosition", 3 },
            .{ "setOrientation", "call_setOrientation", 6 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPosition",
            "setOrientation",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "forwardX", "get_forwardX", null },
            .{ "forwardY", "get_forwardY", null },
            .{ "forwardZ", "get_forwardZ", null },
            .{ "upX", "get_upX", null },
            .{ "upY", "get_upY", null },
            .{ "upZ", "get_upZ", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            positionX: *runtime.Instance = undefined,
            positionY: *runtime.Instance = undefined,
            positionZ: *runtime.Instance = undefined,
            forwardX: *runtime.Instance = undefined,
            forwardY: *runtime.Instance = undefined,
            forwardZ: *runtime.Instance = undefined,
            upX: *runtime.Instance = undefined,
            upY: *runtime.Instance = undefined,
            upZ: *runtime.Instance = undefined,
            _internal: ?*AudioListenerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_forwardX = &get_forwardX,
        .get_forwardY = &get_forwardY,
        .get_forwardZ = &get_forwardZ,
        .get_positionX = &get_positionX,
        .get_positionY = &get_positionY,
        .get_positionZ = &get_positionZ,
        .get_upX = &get_upX,
        .get_upY = &get_upY,
        .get_upZ = &get_upZ,

        .call_setOrientation = &call_setOrientation,
        .call_setPosition = &call_setPosition,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioListenerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioListenerImpl.deinit(instance);
    }

    pub fn get_positionX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_positionX(instance);
    }

    pub fn get_positionY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_positionY(instance);
    }

    pub fn get_positionZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_positionZ(instance);
    }

    pub fn get_forwardX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_forwardX(instance);
    }

    pub fn get_forwardY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_forwardY(instance);
    }

    pub fn get_forwardZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_forwardZ(instance);
    }

    pub fn get_upX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_upX(instance);
    }

    pub fn get_upY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_upY(instance);
    }

    pub fn get_upZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_upZ(instance);
    }

    pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        
        return try AudioListenerImpl.call_setPosition(instance, x, y, z);
    }

    pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32, xUp: f32, yUp: f32, zUp: f32) anyerror!void {
        
        return try AudioListenerImpl.call_setOrientation(instance, x, y, z, xUp, yUp, zUp);
    }

};
