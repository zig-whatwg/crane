//! Generated from: css-color-5.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSColorProfileRuleImpl = @import("impls").CSSColorProfileRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSColorProfileRule = struct {
    pub const Meta = struct {
        pub const name = "CSSColorProfileRule";
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
            .{ "name", "get_name", null },
            .{ "src", "get_src", null },
            .{ "renderingIntent", "get_renderingIntent", null },
            .{ "components", "get_components", null },
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
            .{ "src", "get_src", null },
            .{ "renderingIntent", "get_renderingIntent", null },
            .{ "components", "get_components", null },
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
            src: CSSOMString = undefined,
            renderingIntent: CSSOMString = undefined,
            components: CSSOMString = undefined,
            _internal: ?*CSSColorProfileRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_components = &get_components,
        .get_name = &get_name,
        .get_renderingIntent = &get_renderingIntent,
        .get_src = &get_src,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSColorProfileRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSColorProfileRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSColorProfileRuleImpl.get_name(instance);
    }

    pub fn get_src(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSColorProfileRuleImpl.get_src(instance);
    }

    pub fn get_renderingIntent(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSColorProfileRuleImpl.get_renderingIntent(instance);
    }

    pub fn get_components(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSColorProfileRuleImpl.get_components(instance);
    }

};
