//! Generated from: css-nesting.idl
//! Generated at: 2025-12-05T20:30:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSNestedDeclarationsImpl = @import("impls").CSSNestedDeclarations;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSNestedDeclarations = struct {
    pub const Meta = struct {
        pub const name = "CSSNestedDeclarations";
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
            .{ "style", "get_style", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "style", "get_style", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            style: *runtime.Instance = undefined,
            cached_style: ?*runtime.Instance = null,
            _internal: ?*CSSNestedDeclarationsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_style = &get_style,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSNestedDeclarationsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSNestedDeclarationsImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_style) |cached| {
            return cached;
        }
        const value = try CSSNestedDeclarationsImpl.get_style(instance);
        state.own.cached_style = value;
        return value;
    }
};
