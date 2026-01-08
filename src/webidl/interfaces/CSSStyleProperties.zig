//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSStylePropertiesImpl = @import("impls").CSSStyleProperties;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSStyleProperties = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleProperties";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleDeclaration.State;
        pub const ParentInterface = CSSStyleDeclaration;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cssFloat", "get_cssFloat", "set_cssFloat" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
            "getPropertyValue",
            "getPropertyPriority",
            "setProperty",
            "removeProperty",
            "getPropertyValue",
            "getPropertyCSSValue",
            "removeProperty",
            "getPropertyPriority",
            "setProperty",
            "item",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssFloat", "get_cssFloat", "set_cssFloat" },
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
            cssFloat: typedefs.CSSOMString = undefined,
            _internal: ?*CSSStylePropertiesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_cssFloat = &get_cssFloat,

        .set_cssFloat = &set_cssFloat,

        .call_namedItem = &call_namedItem,
        .call_setNamedItem = &call_setNamedItem,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSStylePropertiesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSStylePropertiesImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSStylePropertiesImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_cssFloat(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSStylePropertiesImpl.get_cssFloat(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_cssFloat(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try CSSStylePropertiesImpl.set_cssFloat(instance, value);
    }

    /// Named property getter for CSS property access
    /// Maps style.color, style.backgroundColor to getPropertyValue()
    /// Per CSS OM spec §6.6.1
    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
        return CSSStylePropertiesImpl.call_namedItem(instance, name);
    }

    /// Named property setter for CSS property access
    /// Maps style.color = "red" to setProperty()
    /// Per CSS OM spec §6.6.1
    pub fn call_setNamedItem(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
        return CSSStylePropertiesImpl.call_setNamedItem(instance, name, value);
    }

    /// Get supported property names for CSS property enumeration
    /// Returns CSS property names that have been set on this declaration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return CSSStylePropertiesImpl.getSupportedPropertyNames(instance, allocator);
    }

};
