//! Generated from: gamepad.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadButtonImpl = @import("impls").GamepadButton;

pub const GamepadButton = struct {
    pub const Meta = struct {
        pub const name = "GamepadButton";
        pub const is_mixin = false;
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
            .{ "pressed", "get_pressed", null },
            .{ "touched", "get_touched", null },
            .{ "value", "get_value", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "pressed", "get_pressed", null },
            .{ "touched", "get_touched", null },
            .{ "value", "get_value", null },
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
            pressed: bool = undefined,
            touched: bool = undefined,
            value: f64 = undefined,
            _internal: ?*GamepadButtonImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_pressed = &get_pressed,
        .get_touched = &get_touched,
        .get_value = &get_value,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GamepadButtonImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadButtonImpl.deinit(instance);
    }

    pub fn get_pressed(instance: *runtime.Instance) anyerror!bool {
        return try GamepadButtonImpl.get_pressed(instance);
    }

    pub fn get_touched(instance: *runtime.Instance) anyerror!bool {
        return try GamepadButtonImpl.get_touched(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f64 {
        return try GamepadButtonImpl.get_value(instance);
    }

};
