//! Generated from: webxr-hand-input.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRJointPoseImpl = @import("impls").XRJointPose;
const XRPose = @import("interfaces").XRPose;

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
        
        // Initialize the instance (Impl receives full instance)
        XRJointPoseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRJointPoseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = try XRJointPoseImpl.get_transform(instance);
        state.cached_transform = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_linearVelocity(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_linearVelocity) |cached| {
            return cached;
        }
        const value = try XRJointPoseImpl.get_linearVelocity(instance);
        state.cached_linearVelocity = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_angularVelocity(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_angularVelocity) |cached| {
            return cached;
        }
        const value = try XRJointPoseImpl.get_angularVelocity(instance);
        state.cached_angularVelocity = value;
        return value;
    }

    pub fn get_emulatedPosition(instance: *runtime.Instance) anyerror!bool {
        return try XRJointPoseImpl.get_emulatedPosition(instance);
    }

    pub fn get_radius(instance: *runtime.Instance) anyerror!f32 {
        return try XRJointPoseImpl.get_radius(instance);
    }

};
