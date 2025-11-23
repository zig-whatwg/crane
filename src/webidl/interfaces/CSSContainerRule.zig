//! Generated from: css-conditional-5.idl
//! Generated at: 2025-11-23T19:17:31Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSContainerRuleImpl = @import("impls").CSSContainerRule;
const CSSConditionRule = @import("interfaces").CSSConditionRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSRuleList = @import("interfaces").CSSRuleList;

pub const CSSContainerRule = struct {
    pub const Meta = struct {
        pub const name = "CSSContainerRule";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSConditionRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "containerName", "get_containerName", null },
            .{ "containerQuery", "get_containerQuery", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "containerName", "get_containerName", null },
            .{ "containerQuery", "get_containerQuery", null },
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
            containerName: CSSOMString = undefined,
            containerQuery: CSSOMString = undefined,
            _internal: ?*CSSContainerRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_containerName = &get_containerName,
        .get_containerQuery = &get_containerQuery,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSContainerRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSContainerRuleImpl.deinit(instance);
    }

    pub fn get_containerName(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSContainerRuleImpl.get_containerName(instance);
    }

    pub fn get_containerQuery(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSContainerRuleImpl.get_containerQuery(instance);
    }

};
