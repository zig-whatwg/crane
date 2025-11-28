//! Generated from: webxr-lighting-estimation.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRLightEstimateImpl = @import("impls").XRLightEstimate;
const mixins = @import("mixins");
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRLightEstimate = struct {
    pub const Meta = struct {
        pub const name = "XRLightEstimate";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sphericalHarmonicsCoefficients", "get_sphericalHarmonicsCoefficients", null },
            .{ "primaryLightDirection", "get_primaryLightDirection", null },
            .{ "primaryLightIntensity", "get_primaryLightIntensity", null },
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
            .{ "sphericalHarmonicsCoefficients", "get_sphericalHarmonicsCoefficients", null },
            .{ "primaryLightDirection", "get_primaryLightDirection", null },
            .{ "primaryLightIntensity", "get_primaryLightIntensity", null },
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
            sphericalHarmonicsCoefficients: runtime.Float32Array = undefined,
            primaryLightDirection: *runtime.Instance = undefined,
            primaryLightIntensity: *runtime.Instance = undefined,
            _internal: ?*XRLightEstimateImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_primaryLightDirection = &get_primaryLightDirection,
        .get_primaryLightIntensity = &get_primaryLightIntensity,
        .get_sphericalHarmonicsCoefficients = &get_sphericalHarmonicsCoefficients,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRLightEstimateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRLightEstimateImpl.deinit(instance);
    }

    pub fn get_sphericalHarmonicsCoefficients(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRLightEstimateImpl.get_sphericalHarmonicsCoefficients(instance);
    }

    pub fn get_primaryLightDirection(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRLightEstimateImpl.get_primaryLightDirection(instance);
    }

    pub fn get_primaryLightIntensity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRLightEstimateImpl.get_primaryLightIntensity(instance);
    }

};
