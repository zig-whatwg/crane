//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSMathClampImpl = @import("../impls/CSSMathClamp.zig");
const CSSMathValue = @import("CSSMathValue.zig");

pub const CSSMathClamp = struct {
    pub const Meta = struct {
        pub const name = "CSSMathClamp";
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
            lower: CSSNumericValue = undefined,
            value: CSSNumericValue = undefined,
            upper: CSSNumericValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSMathClamp, .{
        .deinit_fn = &deinit_wrapper,

        .get_lower = &get_lower,
        .get_operator = &get_operator,
        .get_upper = &get_upper,
        .get_value = &get_value,

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
        CSSMathClampImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSMathClampImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, lower: anyopaque, value: anyopaque, upper: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSMathClampImpl.constructor(state, lower, value, upper);
        
        return instance;
    }

    pub fn get_operator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathClampImpl.get_operator(state);
    }

    pub fn get_lower(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathClampImpl.get_lower(state);
    }

    pub fn get_value(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathClampImpl.get_value(state);
    }

    pub fn get_upper(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathClampImpl.get_upper(state);
    }

    pub fn call_max(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_max(state, values);
    }

    pub fn call_mul(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_mul(state, values);
    }

    pub fn call_add(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_add(state, values);
    }

    pub fn call_toSum(instance: *runtime.Instance, units: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_toSum(state, units);
    }

    pub fn call_equals(instance: *runtime.Instance, value: anyopaque) bool {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_equals(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_parseAll(state, property, cssText);
    }

    pub fn call_sub(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_sub(state, values);
    }

    pub fn call_min(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_min(state, values);
    }

    pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_to(state, unit);
    }

    pub fn call_div(instance: *runtime.Instance, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSMathClampImpl.call_div(state, values);
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
            .USVString_USVString => |a| return CSSMathClampImpl.USVString_USVString(state, a.property, a.cssText),
            .USVString => |arg| return CSSMathClampImpl.USVString(state, arg),
        }
    }

    pub fn call_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMathClampImpl.call_type(state);
    }

};
