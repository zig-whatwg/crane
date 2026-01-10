//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSNumericValueImpl = @import("impls").CSSNumericValue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleValue = @import("CSSStyleValue.zig").CSSStyleValue;
const CSSUnitValue = @import("CSSUnitValue.zig").CSSUnitValue;
const CSSMathSum = @import("CSSMathSum.zig").CSSMathSum;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSNumericValue = struct {
    pub const Meta = struct {
        pub const name = "CSSNumericValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleValue.State;
        pub const ParentInterface = CSSStyleValue;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 0 },
            .{ "sub", "call_sub", 0 },
            .{ "mul", "call_mul", 0 },
            .{ "div", "call_div", 0 },
            .{ "min", "call_min", 0 },
            .{ "max", "call_max", 0 },
            .{ "equals", "call_equals", 0 },
            .{ "to", "call_to", 1 },
            .{ "toSum", "call_toSum", 0 },
            .{ "type", "call_type", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "parse", "call_static_parse", 1 },
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
        struct {
            _internal: ?*CSSNumericValueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_add = &call_add,
        .call_div = &call_div,
        .call_equals = &call_equals,
        .call_max = &call_max,
        .call_min = &call_min,
        .call_mul = &call_mul,
        .call_sub = &call_sub,
        .call_to = &call_to,
        .call_toSum = &call_toSum,
        .call_type = &call_type,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSNumericValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSNumericValueImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSNumericValueImpl.deinit(instance);
    }

    pub fn call_toSum(instance: *runtime.Instance, units: []const runtime.USVString) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_toSum(instance, units);
    }

    pub fn call_sub(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_sub(instance, values);
    }

    pub fn call_equals(instance: *runtime.Instance, value: []const CSSNumberish) anyerror!bool {
        
        return try CSSNumericValueImpl.call_equals(instance, value);
    }

    pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_to(instance, unit);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_static_parse(instance: *runtime.Instance, cssText: runtime.USVString) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_static_parse(instance, cssText);
    }

    pub fn call_min(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_min(instance, values);
    }

    pub fn call_mul(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_mul(instance, values);
    }

    pub fn call_div(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_div(instance, values);
    }

    pub fn call_max(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_max(instance, values);
    }

    pub fn call_type(instance: *runtime.Instance) anyerror!CSSNumericType {
        return try CSSNumericValueImpl.call_type(instance);
    }

    pub fn call_add(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        
        return try CSSNumericValueImpl.call_add(instance, values);
    }

};
