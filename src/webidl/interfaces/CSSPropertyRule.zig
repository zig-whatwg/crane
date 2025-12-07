//! Generated from: css-properties-values-api.idl
//! Generated at: 2025-12-07T20:02:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const CSSPropertyRuleImpl = @import("impls").CSSPropertyRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSPropertyRule = struct {
    pub const Meta = struct {
        pub const name = "CSSPropertyRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSRule.State;
        pub const ParentInterface = CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "syntax", "get_syntax", null },
            .{ "inherits", "get_inherits", null },
            .{ "initialValue", "get_initialValue", null },
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
            .{ "name", "get_name", null },
            .{ "syntax", "get_syntax", null },
            .{ "inherits", "get_inherits", null },
            .{ "initialValue", "get_initialValue", null },
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
            syntax: CSSOMString = undefined,
            inherits: bool = undefined,
            initialValue: ?CSSOMString = null,
            _internal: ?*CSSPropertyRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_inherits = &get_inherits,
        .get_initialValue = &get_initialValue,
        .get_name = &get_name,
        .get_syntax = &get_syntax,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSPropertyRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPropertyRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPropertyRuleImpl.get_name(instance);
    }

    pub fn get_syntax(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPropertyRuleImpl.get_syntax(instance);
    }

    pub fn get_inherits(instance: *runtime.Instance) anyerror!bool {
        return try CSSPropertyRuleImpl.get_inherits(instance);
    }

    pub fn get_initialValue(instance: *runtime.Instance) anyerror!?CSSOMString {
        return try CSSPropertyRuleImpl.get_initialValue(instance);
    }

};
