//! Generated from: navigation-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceTimingConfidenceImpl = @import("impls").PerformanceTimingConfidence;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceTimingConfidenceValue = @import("enums").PerformanceTimingConfidenceValue;

pub const PerformanceTimingConfidence = struct {
    pub const Meta = struct {
        pub const name = "PerformanceTimingConfidence";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "randomizedTriggerRate", "get_randomizedTriggerRate", null },
            .{ "value", "get_value", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "randomizedTriggerRate", "get_randomizedTriggerRate", null },
            .{ "value", "get_value", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            randomizedTriggerRate: f64 = undefined,
            value: enums.PerformanceTimingConfidenceValue = undefined,
            _internal: ?*PerformanceTimingConfidenceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_randomizedTriggerRate = &get_randomizedTriggerRate,
        .get_value = &get_value,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceTimingConfidenceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PerformanceTimingConfidenceImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceTimingConfidenceImpl.deinit(instance);
    }

    pub fn get_randomizedTriggerRate(instance: *runtime.Instance) anyerror!f64 {
        return try PerformanceTimingConfidenceImpl.get_randomizedTriggerRate(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!PerformanceTimingConfidenceValue {
        return try PerformanceTimingConfidenceImpl.get_value(instance);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PerformanceTimingConfidenceImpl.call_toJSON(instance);
    }

};
