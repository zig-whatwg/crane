//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T18:57:57Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMathValueImpl = @import("impls").CSSMathValue;
const mixins = @import("mixins");
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSUnitValue = @import("interfaces").CSSUnitValue;
const CSSMathOperator = @import("enums").CSSMathOperator;
const CSSMathSum = @import("interfaces").CSSMathSum;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSMathValue = struct {
    pub const Meta = struct {
        pub const name = "CSSMathValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSNumericValue;
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
            .{ "operator", "get_operator", null },
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
            .{ "operator", "get_operator", null },
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
            operator: CSSMathOperator = undefined,
            _internal: ?*CSSMathValueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_operator = &get_operator,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMathValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMathValueImpl.deinit(instance);
    }

    pub fn get_operator(instance: *runtime.Instance) anyerror!CSSMathOperator {
        return try CSSMathValueImpl.get_operator(instance);
    }

};
