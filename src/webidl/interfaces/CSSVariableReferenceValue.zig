//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSVariableReferenceValueImpl = @import("impls").CSSVariableReferenceValue;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;
const CSSUnparsedValue = @import("interfaces").CSSUnparsedValue;

pub const CSSVariableReferenceValue = struct {
    pub const Meta = struct {
        pub const name = "CSSVariableReferenceValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            .{ "variable", "get_variable", "set_variable" },
            .{ "fallback", "get_fallback", null },
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
            .{ "variable", "get_variable", "set_variable" },
            .{ "fallback", "get_fallback", null },
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
            variable: runtime.USVString = undefined,
            fallback: ?*runtime.Instance = null,
            _internal: ?*CSSVariableReferenceValueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_fallback = &get_fallback,
        .get_variable = &get_variable,

        .set_variable = &set_variable,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSVariableReferenceValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSVariableReferenceValueImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, variable: runtime.USVString, fallback: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSVariableReferenceValueImpl.call_constructor(allocator, ctx, variable, fallback.value);
    }

    pub fn get_variable(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CSSVariableReferenceValueImpl.get_variable(instance);
    }

    pub fn set_variable(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try CSSVariableReferenceValueImpl.set_variable(instance, value);
    }

    pub fn get_fallback(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSVariableReferenceValueImpl.get_fallback(instance);
    }

};
