//! Generated from: webxr-hand-input.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRJointPoseImpl = @import("../impls/XRJointPose.zig");
const XRPose = @import("XRPose.zig");

pub const XRJointPose = struct {
    pub const Meta = struct {
        pub const name = "XRJointPose";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRPose;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            radius: f32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRJointPose, .{
        .deinit_fn = &deinit_wrapper,

        .get_angularVelocity = &get_angularVelocity,
        .get_emulatedPosition = &get_emulatedPosition,
        .get_linearVelocity = &get_linearVelocity,
        .get_radius = &get_radius,
        .get_transform = &get_transform,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRJointPoseImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRJointPoseImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = XRJointPoseImpl.get_transform(state);
        state.cached_transform = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_linearVelocity(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_linearVelocity) |cached| {
            return cached;
        }
        const value = XRJointPoseImpl.get_linearVelocity(state);
        state.cached_linearVelocity = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_angularVelocity(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_angularVelocity) |cached| {
            return cached;
        }
        const value = XRJointPoseImpl.get_angularVelocity(state);
        state.cached_angularVelocity = value;
        return value;
    }

    pub fn get_emulatedPosition(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRJointPoseImpl.get_emulatedPosition(state);
    }

    pub fn get_radius(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XRJointPoseImpl.get_radius(state);
    }

};
