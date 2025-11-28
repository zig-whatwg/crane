//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMathSumImpl = @import("impls").CSSMathSum;
const mixins = @import("mixins");
const CSSMathValue = @import("interfaces").CSSMathValue;
const CSSNumericArray = @import("interfaces").CSSNumericArray;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSUnitValue = @import("interfaces").CSSUnitValue;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSMathOperator = @import("enums").CSSMathOperator;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSMathSum = struct {
    pub const Meta = struct {
        pub const name = "CSSMathSum";
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
            .{ "values", "get_values", null },
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
            .{ "values", "get_values", null },
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
            values: *runtime.Instance = undefined,
            _internal: ?*CSSMathSumImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_values = &get_values,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMathSumImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMathSumImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: []const CSSNumberish) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSMathSumImpl.call_constructor(allocator, ctx, args);
    }

    pub fn get_values(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMathSumImpl.get_values(instance);
    }

};
