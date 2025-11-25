//! Generated from: webaudio.idl
//! Generated at: 2025-11-25T14:21:39Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioParamImpl = @import("impls").AudioParam;
const AutomationRate = @import("enums").AutomationRate;

pub const AudioParam = struct {
    pub const Meta = struct {
        pub const name = "AudioParam";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "value", "get_value", "set_value" },
            .{ "automationRate", "get_automationRate", "set_automationRate" },
            .{ "defaultValue", "get_defaultValue", null },
            .{ "minValue", "get_minValue", null },
            .{ "maxValue", "get_maxValue", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "setValueAtTime", "call_setValueAtTime", 2 },
            .{ "linearRampToValueAtTime", "call_linearRampToValueAtTime", 2 },
            .{ "exponentialRampToValueAtTime", "call_exponentialRampToValueAtTime", 2 },
            .{ "setTargetAtTime", "call_setTargetAtTime", 3 },
            .{ "setValueCurveAtTime", "call_setValueCurveAtTime", 3 },
            .{ "cancelScheduledValues", "call_cancelScheduledValues", 1 },
            .{ "cancelAndHoldAtTime", "call_cancelAndHoldAtTime", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setValueAtTime",
            "linearRampToValueAtTime",
            "exponentialRampToValueAtTime",
            "setTargetAtTime",
            "setValueCurveAtTime",
            "cancelScheduledValues",
            "cancelAndHoldAtTime",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "value", "get_value", "set_value" },
            .{ "automationRate", "get_automationRate", "set_automationRate" },
            .{ "defaultValue", "get_defaultValue", null },
            .{ "minValue", "get_minValue", null },
            .{ "maxValue", "get_maxValue", null },
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
            value: f32 = undefined,
            automationRate: AutomationRate = undefined,
            defaultValue: f32 = undefined,
            minValue: f32 = undefined,
            maxValue: f32 = undefined,
            _internal: ?*AudioParamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_automationRate = &get_automationRate,
        .get_defaultValue = &get_defaultValue,
        .get_maxValue = &get_maxValue,
        .get_minValue = &get_minValue,
        .get_value = &get_value,

        .set_automationRate = &set_automationRate,
        .set_value = &set_value,

        .call_cancelAndHoldAtTime = &call_cancelAndHoldAtTime,
        .call_cancelScheduledValues = &call_cancelScheduledValues,
        .call_exponentialRampToValueAtTime = &call_exponentialRampToValueAtTime,
        .call_linearRampToValueAtTime = &call_linearRampToValueAtTime,
        .call_setTargetAtTime = &call_setTargetAtTime,
        .call_setValueAtTime = &call_setValueAtTime,
        .call_setValueCurveAtTime = &call_setValueCurveAtTime,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioParamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioParamImpl.deinit(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: f32) anyerror!void {
        try AudioParamImpl.set_value(instance, value);
    }

    pub fn get_automationRate(instance: *runtime.Instance) anyerror!AutomationRate {
        return try AudioParamImpl.get_automationRate(instance);
    }

    pub fn set_automationRate(instance: *runtime.Instance, value: AutomationRate) anyerror!void {
        try AudioParamImpl.set_automationRate(instance, value);
    }

    pub fn get_defaultValue(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_defaultValue(instance);
    }

    pub fn get_minValue(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_minValue(instance);
    }

    pub fn get_maxValue(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_maxValue(instance);
    }

    pub fn call_exponentialRampToValueAtTime(instance: *runtime.Instance, value: f32, endTime: f64) anyerror!*runtime.Instance {
        
        return try AudioParamImpl.call_exponentialRampToValueAtTime(instance, value, endTime);
    }

    pub fn call_cancelAndHoldAtTime(instance: *runtime.Instance, cancelTime: f64) anyerror!*runtime.Instance {
        
        return try AudioParamImpl.call_cancelAndHoldAtTime(instance, cancelTime);
    }

    pub fn call_setValueAtTime(instance: *runtime.Instance, value: f32, startTime: f64) anyerror!*runtime.Instance {
        
        return try AudioParamImpl.call_setValueAtTime(instance, value, startTime);
    }

    pub fn call_cancelScheduledValues(instance: *runtime.Instance, cancelTime: f64) anyerror!*runtime.Instance {
        
        return try AudioParamImpl.call_cancelScheduledValues(instance, cancelTime);
    }

    pub fn call_setValueCurveAtTime(instance: *runtime.Instance, values: *const anyopaque, startTime: f64, duration: f64) anyerror!*runtime.Instance {
        
        return try AudioParamImpl.call_setValueCurveAtTime(instance, values, startTime, duration);
    }

    pub fn call_linearRampToValueAtTime(instance: *runtime.Instance, value: f32, endTime: f64) anyerror!*runtime.Instance {
        
        return try AudioParamImpl.call_linearRampToValueAtTime(instance, value, endTime);
    }

    pub fn call_setTargetAtTime(instance: *runtime.Instance, target: f32, startTime: f64, timeConstant: f32) anyerror!*runtime.Instance {
        
        return try AudioParamImpl.call_setTargetAtTime(instance, target, startTime, timeConstant);
    }

};
