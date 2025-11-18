//! Generated from: webxr-lighting-estimation.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRLightEstimateImpl = @import("../impls/XRLightEstimate.zig");

pub const XRLightEstimate = struct {
    pub const Meta = struct {
        pub const name = "XRLightEstimate";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sphericalHarmonicsCoefficients: Float32Array = undefined,
            primaryLightDirection: DOMPointReadOnly = undefined,
            primaryLightIntensity: DOMPointReadOnly = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRLightEstimate, .{
        .deinit_fn = &deinit_wrapper,

        .get_primaryLightDirection = &get_primaryLightDirection,
        .get_primaryLightIntensity = &get_primaryLightIntensity,
        .get_sphericalHarmonicsCoefficients = &get_sphericalHarmonicsCoefficients,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRLightEstimateImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRLightEstimateImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sphericalHarmonicsCoefficients(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRLightEstimateImpl.get_sphericalHarmonicsCoefficients(state);
    }

    pub fn get_primaryLightDirection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRLightEstimateImpl.get_primaryLightDirection(state);
    }

    pub fn get_primaryLightIntensity(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRLightEstimateImpl.get_primaryLightIntensity(state);
    }

};
