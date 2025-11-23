//! Generated from: css-animations.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSKeyframeRuleImpl = @import("impls").CSSKeyframeRule;
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSOMString = @import("interfaces").CSSOMString;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const DOMString = @import("typedefs").DOMString;

pub const CSSKeyframeRule = struct {
    pub const Meta = struct {
        pub const name = "CSSKeyframeRule";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "keyText", "get_keyText", "set_keyText" },
            .{ "style", "get_style", null },
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
            .{ "keyText", "get_keyText", "set_keyText" },
            .{ "style", "get_style", null },
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
            keyText: CSSOMString = undefined,
            style: CSSStyleProperties = undefined,
            cached_style: ?CSSStyleProperties = null,
        },
    );

    const delegates = .{

        .get_keyText = &get_keyText,
        .get_style = &get_style,

        .set_keyText = &set_keyText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSKeyframeRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSKeyframeRuleImpl.deinit(instance);
    }

    pub fn get_keyText(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CSSKeyframeRuleImpl.get_keyText(instance);
    }

    pub fn set_keyText(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try CSSKeyframeRuleImpl.set_keyText(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!CSSStyleProperties {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_style) |cached| {
            return cached;
        }
        const value = try CSSKeyframeRuleImpl.get_style(instance);
        state.own.cached_style = value;
        return value;
    }

};
