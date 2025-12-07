//! Generated from: css-typed-om.idl
//! Generated at: 2025-12-07T20:02:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const CSSKeywordValueImpl = @import("impls").CSSKeywordValue;
const mixins = @import("mixins");
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSKeywordValue = struct {
    pub const Meta = struct {
        pub const name = "CSSKeywordValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleValue.State;
        pub const ParentInterface = CSSStyleValue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "value", "get_value", "set_value" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parse",
            "parseAll",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "value", "get_value", "set_value" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            value: runtime.USVString = undefined,
            _internal: ?*CSSKeywordValueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_value = &get_value,

        .set_value = &set_value,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSKeywordValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSKeywordValueImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, value: runtime.USVString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSKeywordValueImpl.call_constructor(allocator, ctx, value);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CSSKeywordValueImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try CSSKeywordValueImpl.set_value(instance, value);
    }

};
