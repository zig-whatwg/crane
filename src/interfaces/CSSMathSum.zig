//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSMathSumImpl = @import("../impls/CSSMathSum.zig");
const CSSMathValue = @import("CSSMathValue.zig");

pub const CSSMathSum = struct {
    pub const Meta = struct {
        pub const name = "CSSMathSum";
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

    pub const vtable = runtime.buildVTable(CSSMathSum, .{
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
        
        // Initialize the state (Impl receives full hierarchy)
        CSSMathSumImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSMathSumImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, args: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSMathSumImpl.constructor(state, args);
        
        return instance;
    }

    pub fn get_operator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathSumImpl.get_operator(state);
    }

    pub fn get_values(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathSumImpl.get_values(state);
    }

    pub fn call_max(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_max(state, values);
    }

    pub fn call_mul(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_mul(state, values);
    }

    pub fn call_add(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_add(state, values);
    }

    pub fn call_toSum(instance: *runtime.Instance, units: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_toSum(state, units);
    }

    pub fn call_equals(instance: *runtime.Instance, value: anyopaque) bool {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_equals(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_parseAll(state, property, cssText);
    }

    pub fn call_sub(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_sub(state, values);
    }

    pub fn call_min(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_min(state, values);
    }

    pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_to(state, unit);
    }

    pub fn call_div(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathSumImpl.call_div(state, values);
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

    pub fn call_parse(instance: *runtime.Instance, args: ParseArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString_USVString => |a| return CSSMathSumImpl.USVString_USVString(state, a.property, a.cssText),
            .USVString => |arg| return CSSMathSumImpl.USVString(state, arg),
        }
    }

    pub fn call_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathSumImpl.call_type(state);
    }

};
