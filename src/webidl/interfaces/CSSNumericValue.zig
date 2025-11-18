//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:12Z
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

pub const CSSNumericValue = struct {
    pub const Meta = struct {
        pub const name = "CSSNumericValue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleValue;
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSNumericValue, .{
        .deinit_fn = &deinit_wrapper,

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
        CSSNumericValueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSNumericValueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_max(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSNumericValueImpl.call_max(instance, values);
    }

    pub fn call_mul(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSNumericValueImpl.call_mul(instance, values);
    }

    pub fn call_add(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSNumericValueImpl.call_add(instance, values);
    }

    pub fn call_toSum(instance: *runtime.Instance, units: runtime.USVString) anyerror!CSSMathSum {
        
        return try CSSNumericValueImpl.call_toSum(instance, units);
    }

    pub fn call_equals(instance: *runtime.Instance, value: CSSNumberish) anyerror!bool {
        
        return try CSSNumericValueImpl.call_equals(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSNumericValueImpl.call_parseAll(instance, property, cssText);
    }

    pub fn call_sub(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSNumericValueImpl.call_sub(instance, values);
    }

    pub fn call_min(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSNumericValueImpl.call_min(instance, values);
    }

    pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyerror!CSSUnitValue {
        
        return try CSSNumericValueImpl.call_to(instance, unit);
    }

    pub fn call_div(instance: *runtime.Instance, values: CSSNumberish) anyerror!CSSNumericValue {
        
        return try CSSNumericValueImpl.call_div(instance, values);
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
            .USVString_USVString => |a| return try CSSNumericValueImpl.USVString_USVString(instance, a.property, a.cssText),
            .USVString => |arg| return try CSSNumericValueImpl.USVString(instance, arg),
        }
    }

    pub fn call_type(instance: *runtime.Instance) anyerror!CSSNumericType {
        return try CSSNumericValueImpl.call_type(instance);
    }

};
