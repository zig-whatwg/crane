//! Generated from: orientation-event.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DeviceMotionEventRotationRateImpl = @import("impls").DeviceMotionEventRotationRate;
const mixins = @import("mixins");

pub const DeviceMotionEventRotationRate = struct {
    pub const Meta = struct {
        pub const name = "DeviceMotionEventRotationRate";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "alpha", "get_alpha", null },
            .{ "beta", "get_beta", null },
            .{ "gamma", "get_gamma", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "alpha", "get_alpha", null },
            .{ "beta", "get_beta", null },
            .{ "gamma", "get_gamma", null },
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
            alpha: ?f64 = null,
            beta: ?f64 = null,
            gamma: ?f64 = null,
            _internal: ?*DeviceMotionEventRotationRateImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alpha = &get_alpha,
        .get_beta = &get_beta,
        .get_gamma = &get_gamma,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DeviceMotionEventRotationRateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DeviceMotionEventRotationRateImpl.deinit(instance);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceMotionEventRotationRateImpl.get_alpha(instance);
    }

    pub fn get_beta(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceMotionEventRotationRateImpl.get_beta(instance);
    }

    pub fn get_gamma(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceMotionEventRotationRateImpl.get_gamma(instance);
    }

};
