//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMathInvertImpl = @import("impls").CSSMathInvert;
const mixins = @import("mixins");
const CSSMathValue = @import("interfaces").CSSMathValue;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSUnitValue = @import("interfaces").CSSUnitValue;
const CSSMathSum = @import("interfaces").CSSMathSum;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSMathOperator = @import("enums").CSSMathOperator;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSMathInvert = struct {
    pub const Meta = struct {
        pub const name = "CSSMathInvert";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSMathValue;
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
            .{ "value", "get_value", null },
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
            "add",
            "sub",
            "mul",
            "div",
            "min",
            "max",
            "equals",
            "to",
            "toSum",
            "type",
            "parse",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "value", "get_value", null },
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
            value: *runtime.Instance = undefined,
            _internal: ?*CSSMathInvertImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_value = &get_value,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMathInvertImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMathInvertImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, arg: CSSNumberish) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSMathInvertImpl.call_constructor(allocator, ctx, arg);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMathInvertImpl.get_value(instance);
    }

};
