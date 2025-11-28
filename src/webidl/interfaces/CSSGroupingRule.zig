//! Generated from: cssom.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSGroupingRuleImpl = @import("impls").CSSGroupingRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;
const CSSRuleList = @import("interfaces").CSSRuleList;

pub const CSSGroupingRule = struct {
    pub const Meta = struct {
        pub const name = "CSSGroupingRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "cssRules", "get_cssRules", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "insertRule", "call_insertRule", 1 },
            .{ "deleteRule", "call_deleteRule", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "insertRule",
            "deleteRule",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssRules", "get_cssRules", null },
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
            cssRules: *runtime.Instance = undefined,
            cached_cssRules: ?*runtime.Instance = null,
            _internal: ?*CSSGroupingRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_cssRules = &get_cssRules,

        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSGroupingRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSGroupingRuleImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cssRules) |cached| {
            return cached;
        }
        const value = try CSSGroupingRuleImpl.get_cssRules(instance);
        state.own.cached_cssRules = value;
        return value;
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try CSSGroupingRuleImpl.call_deleteRule(instance, index);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: CSSOMString, index: webidl.Opt(u32)) anyerror!u32 {
        
        return try CSSGroupingRuleImpl.call_insertRule(instance, rule, index);
    }

};
