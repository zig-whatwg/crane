//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ElementCSSInlineStyleImpl = @import("impls").ElementCSSInlineStyle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleProperties = @import("CSSStyleProperties.zig").CSSStyleProperties;
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig").CSSStyleDeclaration;
const StylePropertyMap = @import("StylePropertyMap.zig").StylePropertyMap;

pub const ElementCSSInlineStyle = struct {
    pub const Meta = struct {
        pub const name = "ElementCSSInlineStyle";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "style", "get_style", "set_style" },
            .{ "attributeStyleMap", "get_attributeStyleMap", null },
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
            .{ "style", "get_style", "set_style" },
            .{ "attributeStyleMap", "get_attributeStyleMap", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            style: *runtime.Instance = undefined,
            attributeStyleMap: *runtime.Instance = undefined,
            cached_style: ?*runtime.Instance = null,
            cached_attributeStyleMap: ?*runtime.Instance = null,
            _internal: ?*ElementCSSInlineStyleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_attributeStyleMap = &get_attributeStyleMap,
        .get_style = &get_style,

        .set_style = &set_style,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ElementCSSInlineStyleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ElementCSSInlineStyleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ElementCSSInlineStyleImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_style) |cached| {
            return cached;
        }
        const value = try ElementCSSInlineStyleImpl.get_style(instance);
        state.own.cached_style = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn set_style(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'style' forwards to 'cssText' on the attribute's value
        const target = try get_style(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        // Note: target is a *Instance, use setPropertyOnInstance
        try runtime.setPropertyOnInstance(target, "cssText", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_attributeStyleMap) |cached| {
            return cached;
        }
        const value = try ElementCSSInlineStyleImpl.get_attributeStyleMap(instance);
        state.own.cached_attributeStyleMap = value;
        return value;
    }

};
