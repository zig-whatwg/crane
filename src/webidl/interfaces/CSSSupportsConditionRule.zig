//! Generated from: css-conditional-5.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSSupportsConditionRuleImpl = @import("impls").CSSSupportsConditionRule;
const CSSGroupingRule = @import("interfaces").CSSGroupingRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSRuleList = @import("interfaces").CSSRuleList;

pub const CSSSupportsConditionRule = struct {
    pub const Meta = struct {
        pub const name = "CSSSupportsConditionRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSGroupingRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
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
            .{ "name", "get_name", null },
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
            _internal: ?*CSSSupportsConditionRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSSupportsConditionRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSSupportsConditionRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSSupportsConditionRuleImpl.get_name(instance);
    }

};
