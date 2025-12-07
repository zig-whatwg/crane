//! Generated from: css-view-transitions.idl
//! Generated at: 2025-12-07T20:02:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const CSSViewTransitionRuleImpl = @import("impls").CSSViewTransitionRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSViewTransitionRule = struct {
    pub const Meta = struct {
        pub const name = "CSSViewTransitionRule";
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
            .{ "navigation", "get_navigation", null },
            .{ "types", "get_types", null },
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
            .{ "navigation", "get_navigation", null },
            .{ "types", "get_types", null },
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
            navigation: CSSOMString = undefined,
            types: runtime.FrozenArray(CSSOMString) = undefined,
            cached_types: ?runtime.FrozenArray(CSSOMString) = null,
            _internal: ?*CSSViewTransitionRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_navigation = &get_navigation,
        .get_types = &get_types,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSViewTransitionRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSViewTransitionRuleImpl.deinit(instance);
    }

    pub fn get_navigation(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSViewTransitionRuleImpl.get_navigation(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_types(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_types) |cached| {
            return cached;
        }
        const value = try CSSViewTransitionRuleImpl.get_types(instance);
        state.own.cached_types = value;
        return value;
    }

};
