//! Generated from: css-animations.idl
//! Generated at: 2025-11-23T16:59:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSKeyframesRuleImpl = @import("impls").CSSKeyframesRule;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSKeyframeRule = @import("interfaces").CSSKeyframeRule;
const CSSRuleList = @import("interfaces").CSSRuleList;

pub const CSSKeyframesRule = struct {
    pub const Meta = struct {
        pub const name = "CSSKeyframesRule";
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
            .{ "name", "get_name", "set_name" },
            .{ "cssRules", "get_cssRules", null },
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "appendRule", "call_appendRule", 1 },
            .{ "deleteRule", "call_deleteRule", 1 },
            .{ "findRule", "call_findRule", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "appendRule",
            "deleteRule",
            "findRule",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", "set_name" },
            .{ "cssRules", "get_cssRules", null },
            .{ "length", "get_length", null },
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
            name: CSSOMString = undefined,
            cssRules: CSSRuleList = undefined,
            length: u32 = undefined,
            _internal: ?*CSSKeyframesRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_cssRules = &get_cssRules,
        .get_length = &get_length,
        .get_name = &get_name,

        .set_name = &set_name,

        .call_appendRule = &call_appendRule,
        .call_deleteRule = &call_deleteRule,
        .call_findRule = &call_findRule,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSKeyframesRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSKeyframesRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSKeyframesRuleImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSKeyframesRuleImpl.set_name(instance, value);
    }

    pub fn get_cssRules(instance: *runtime.Instance) anyerror!CSSRuleList {
        return try CSSKeyframesRuleImpl.get_cssRules(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSKeyframesRuleImpl.get_length(instance);
    }

    pub fn call_deleteRule(instance: *runtime.Instance, select: CSSOMString) anyerror!void {
        
        return try CSSKeyframesRuleImpl.call_deleteRule(instance, select);
    }

    pub fn call_findRule(instance: *runtime.Instance, select: CSSOMString) anyerror!CSSKeyframeRule {
        
        return try CSSKeyframesRuleImpl.call_findRule(instance, select);
    }

    pub fn call_appendRule(instance: *runtime.Instance, rule: CSSOMString) anyerror!void {
        
        return try CSSKeyframesRuleImpl.call_appendRule(instance, rule);
    }

};
