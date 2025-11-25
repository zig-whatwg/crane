//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RGBColorImpl = @import("impls").RGBColor;
const CSSPrimitiveValue = @import("interfaces").CSSPrimitiveValue;

pub const RGBColor = struct {
    pub const Meta = struct {
        pub const name = "RGBColor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "red", "get_red", null },
            .{ "green", "get_green", null },
            .{ "blue", "get_blue", null },
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
            .{ "red", "get_red", null },
            .{ "green", "get_green", null },
            .{ "blue", "get_blue", null },
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
            red: *runtime.Instance = undefined,
            green: *runtime.Instance = undefined,
            blue: *runtime.Instance = undefined,
            _internal: ?*RGBColorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_blue = &get_blue,
        .get_green = &get_green,
        .get_red = &get_red,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RGBColorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RGBColorImpl.deinit(instance);
    }

    pub fn get_red(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RGBColorImpl.get_red(instance);
    }

    pub fn get_green(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RGBColorImpl.get_green(instance);
    }

    pub fn get_blue(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RGBColorImpl.get_blue(instance);
    }

};
