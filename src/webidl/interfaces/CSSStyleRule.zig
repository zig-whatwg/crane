//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSStyleRuleImpl = @import("impls").CSSStyleRule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSGroupingRule = @import("interfaces").CSSGroupingRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const CSSRuleList = @import("interfaces").CSSRuleList;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const DOMString = @import("typedefs").DOMString;

pub const CSSStyleRule = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSGroupingRule.State;
        pub const ParentInterface = CSSGroupingRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "selectorText", "get_selectorText", "set_selectorText" },
            .{ "style", "get_style", "set_style" },
            .{ "styleMap", "get_styleMap", null },
        };
        
        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "style", "cssText" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "insertRule",
            "deleteRule",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "selectorText", "get_selectorText", "set_selectorText" },
            .{ "style", "get_style", "set_style" },
            .{ "styleMap", "get_styleMap", null },
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
            selectorText: typedefs.CSSOMString = undefined,
            style: *runtime.Instance = undefined,
            styleMap: *runtime.Instance = undefined,
            cached_style: ?*runtime.Instance = null,
            cached_styleMap: ?*runtime.Instance = null,
            _internal: ?*CSSStyleRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_selectorText = &get_selectorText,
        .get_style = &get_style,
        .get_styleMap = &get_styleMap,

        .set_selectorText = &set_selectorText,
        .set_style = &set_style,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSStyleRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSStyleRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSStyleRuleImpl.deinit(instance);
    }

    pub fn get_selectorText(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSStyleRuleImpl.get_selectorText(instance);
    }

    pub fn set_selectorText(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSStyleRuleImpl.set_selectorText(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_style) |cached| {
            return cached;
        }
        const value = try CSSStyleRuleImpl.get_style(instance);
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
    pub fn get_styleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_styleMap) |cached| {
            return cached;
        }
        const value = try CSSStyleRuleImpl.get_styleMap(instance);
        state.own.cached_styleMap = value;
        return value;
    }

};
