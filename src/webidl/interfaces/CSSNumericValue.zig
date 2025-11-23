//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-23T19:17:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSNumericValueImpl = @import("impls").CSSNumericValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSUnitValue = @import("interfaces").CSSUnitValue;
const CSSMathSum = @import("interfaces").CSSMathSum;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSNumericValue = struct {
    pub const Meta = struct {
        pub const name = "CSSNumericValue";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleValue;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "add", "call_add", 1 },
            .{ "sub", "call_sub", 1 },
            .{ "mul", "call_mul", 1 },
            .{ "div", "call_div", 1 },
            .{ "min", "call_min", 1 },
            .{ "max", "call_max", 1 },
            .{ "equals", "call_equals", 1 },
            .{ "to", "call_to", 1 },
            .{ "toSum", "call_toSum", 1 },
            .{ "type", "call_type", 0 },
            .{ "parse", "call_parse", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parseAll",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_add = &call_add,
        .call_div = &call_div,
        .call_equals = &call_equals,
        .call_max = &call_max,
        .call_min = &call_min,
        .call_mul = &call_mul,
        .call_parse = &call_parse,
        .call_sub = &call_sub,
        .call_to = &call_to,
        .call_toSum = &call_toSum,
        .call_type = &call_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSNumericValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSNumericValueImpl.deinit(instance);
    }

    pub fn call_equals(instance: *runtime.Instance, value: CSSNumberish) anyerror!bool {
        
        return try CSSNumericValueImpl.call_equals(instance, value);
    }

    pub fn call_max(instance: *runtime.Instance, values: CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_max(instance, values);
    }

    pub fn call_sub(instance: *runtime.Instance, values: CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_sub(instance, values);
    }

    pub fn call_min(instance: *runtime.Instance, values: CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_min(instance, values);
    }

    pub fn call_mul(instance: *runtime.Instance, values: CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_mul(instance, values);
    }

    pub fn call_add(instance: *runtime.Instance, values: CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_add(instance, values);
    }

    pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_to(instance, unit);
    }

    pub fn call_toSum(instance: *runtime.Instance, units: runtime.USVString) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_toSum(instance, units);
    }

    pub fn call_div(instance: *runtime.Instance, values: CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_div(instance, values);
    }

    pub fn call_type(instance: *runtime.Instance) anyerror!CSSNumericType {
        return try CSSNumericValueImpl.call_type(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parse(instance: *runtime.Instance, cssText: runtime.USVString) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_parse(instance, cssText);
    }

};
