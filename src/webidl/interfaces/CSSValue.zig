//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSValueImpl = @import("impls").CSSValue;
const DOMString = @import("typedefs").DOMString;

pub const CSSValue = struct {
    pub const Meta = struct {
        pub const name = "CSSValue";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "cssValueType", "get_cssValueType", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "CSS_INHERIT", "get_CSS_INHERIT" },
            .{ "CSS_PRIMITIVE_VALUE", "get_CSS_PRIMITIVE_VALUE" },
            .{ "CSS_VALUE_LIST", "get_CSS_VALUE_LIST" },
            .{ "CSS_CUSTOM", "get_CSS_CUSTOM" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "cssValueType", "get_cssValueType", null },
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
            cssText: runtime.DOMString = undefined,
            cssValueType: u16 = undefined,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short CSS_INHERIT = 0;
    pub fn get_CSS_INHERIT() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short CSS_PRIMITIVE_VALUE = 1;
    pub fn get_CSS_PRIMITIVE_VALUE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CSS_VALUE_LIST = 2;
    pub fn get_CSS_VALUE_LIST() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short CSS_CUSTOM = 3;
    pub fn get_CSS_CUSTOM() u16 {
        return 3;
    }

    const delegates = .{

        .get_CSS_CUSTOM = &get_CSS_CUSTOM,
        .get_CSS_INHERIT = &get_CSS_INHERIT,
        .get_CSS_PRIMITIVE_VALUE = &get_CSS_PRIMITIVE_VALUE,
        .get_CSS_VALUE_LIST = &get_CSS_VALUE_LIST,
        .get_cssText = &get_cssText,
        .get_cssValueType = &get_cssValueType,

        .set_cssText = &set_cssText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSValueImpl.deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSValueImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSValueImpl.set_cssText(instance, value);
    }

    pub fn get_cssValueType(instance: *runtime.Instance) anyerror!u16 {
        return try CSSValueImpl.get_cssValueType(instance);
    }

};
