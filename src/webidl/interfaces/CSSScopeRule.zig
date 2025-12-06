//! Generated from: css-cascade-6.idl
//! Generated at: 2025-12-05T20:30:48Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSScopeRuleImpl = @import("impls").CSSScopeRule;
const mixins = @import("mixins");
const CSSGroupingRule = @import("interfaces").CSSGroupingRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSRuleList = @import("interfaces").CSSRuleList;

pub const CSSScopeRule = struct {
    pub const Meta = struct {
        pub const name = "CSSScopeRule";
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
            .{ "start", "get_start", null },
            .{ "end", "get_end", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "insertRule",
            "deleteRule",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "start", "get_start", null },
            .{ "end", "get_end", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            start: ?CSSOMString = null,
            end: ?CSSOMString = null,
            _internal: ?*CSSScopeRuleImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_end = &get_end,
        .get_start = &get_start,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSScopeRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSScopeRuleImpl.deinit(instance);
    }

    pub fn get_start(instance: *runtime.Instance) anyerror!?CSSOMString {
        return try CSSScopeRuleImpl.get_start(instance);
    }

    pub fn get_end(instance: *runtime.Instance) anyerror!?CSSOMString {
        return try CSSScopeRuleImpl.get_end(instance);
    }
};
