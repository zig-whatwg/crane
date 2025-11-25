//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RectImpl = @import("impls").Rect;
const CSSPrimitiveValue = @import("interfaces").CSSPrimitiveValue;

pub const Rect = struct {
    pub const Meta = struct {
        pub const name = "Rect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "top", "get_top", null },
            .{ "right", "get_right", null },
            .{ "bottom", "get_bottom", null },
            .{ "left", "get_left", null },
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
            .{ "top", "get_top", null },
            .{ "right", "get_right", null },
            .{ "bottom", "get_bottom", null },
            .{ "left", "get_left", null },
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
            top: *runtime.Instance = undefined,
            right: *runtime.Instance = undefined,
            bottom: *runtime.Instance = undefined,
            left: *runtime.Instance = undefined,
            _internal: ?*RectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_bottom = &get_bottom,
        .get_left = &get_left,
        .get_right = &get_right,
        .get_top = &get_top,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RectImpl.deinit(instance);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_top(instance);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_right(instance);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_bottom(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_left(instance);
    }

};
