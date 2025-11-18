//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSMathProductImpl = @import("impls").CSSMathProduct;
const CSSMathValue = @import("interfaces").CSSMathValue;
const CSSNumericArray = @import("interfaces").CSSNumericArray;
const CSSNumberish = @import("typedefs").CSSNumberish;

pub const CSSMathProduct = struct {
    pub const Meta = struct {
        pub const name = "CSSMathProduct";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSMathValue;
        pub const MixinTypes = .{};
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
    };

    pub const State = runtime.FlattenedState(
        struct {
            values: CSSNumericArray = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSMathProduct, .{
        .deinit_fn = &deinit_wrapper,

        .get_operator = &get_operator,
        .get_values = &get_values,

        .call_add = &call_add,
        .call_div = &call_div,
        .call_equals = &call_equals,
        .call_max = &call_max,
        .call_min = &call_min,
        .call_mul = &call_mul,
        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
        .call_sub = &call_sub,
        .call_to = &call_to,
        .call_toSum = &call_toSum,
        .call_type = &call_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSMathProductImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMathProductImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, args: CSSNumberish) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSMathProductImpl.constructor(instance, args);
        
        return instance;
    }

    pub fn get_operator(instance: *runtime.Instance) anyerror!CSSMathOperator {
        return try CSSMathProductImpl.get_operator(instance);
    }

    pub fn get_values(instance: *runtime.Instance) anyerror!CSSNumericArray {
        return try CSSMathProductImpl.get_values(instance);
    }

    pub fn call_max(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSMathProductImpl.call_max(instance, values);
    }

    pub fn call_mul(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSMathProductImpl.call_mul(instance, values);
    }

    pub fn call_add(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSMathProductImpl.call_add(instance, values);
    }

    pub fn call_toSum(instance: *runtime.Instance, units: runtime.USVString) anyerror!CSSMathSum {
        
        return try CSSMathProductImpl.call_toSum(instance, units);
    }

    pub fn call_equals(instance: *runtime.Instance, value: CSSNumberish) anyerror!bool {
        
        return try CSSMathProductImpl.call_equals(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSMathProductImpl.call_parseAll(instance, property, cssText);
    }

    pub fn call_sub(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSMathProductImpl.call_sub(instance, values);
    }

    pub fn call_min(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSMathProductImpl.call_min(instance, values);
    }

    pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyerror!CSSUnitValue {
        
        return try CSSMathProductImpl.call_to(instance, unit);
    }

    pub fn call_div(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSMathProductImpl.call_div(instance, values);
    }

    /// Arguments for parse (WebIDL overloading)
    pub const ParseArgs = union(enum) {
        /// parse(property, cssText)
        USVString_USVString: struct {
            property: runtime.USVString,
            cssText: runtime.USVString,
        },
        /// parse(cssText)
        USVString: runtime.USVString,
    };

    pub fn call_parse(instance: *runtime.Instance, args: ParseArgs) anyerror!CSSStyleValue {
        switch (args) {
            .USVString_USVString => |a| return try CSSMathProductImpl.USVString_USVString(instance, a.property, a.cssText),
            .USVString => |arg| return try CSSMathProductImpl.USVString(instance, arg),
        }
    }

    pub fn call_type(instance: *runtime.Instance) anyerror!CSSNumericType {
        return try CSSMathProductImpl.call_type(instance);
    }

};
