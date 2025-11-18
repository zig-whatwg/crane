//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRPoseImpl = @import("impls").XRPose;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRPose = struct {
    pub const Meta = struct {
        pub const name = "XRPose";
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
            transform: XRRigidTransform = undefined,
            linearVelocity: ?DOMPointReadOnly = null,
            angularVelocity: ?DOMPointReadOnly = null,
            emulatedPosition: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRPose, .{
        .deinit_fn = &deinit_wrapper,

        .get_angularVelocity = &get_angularVelocity,
        .get_emulatedPosition = &get_emulatedPosition,
        .get_linearVelocity = &get_linearVelocity,
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
        XRPoseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRPoseImpl.deinit(instance);
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
        const value = try XRPoseImpl.get_transform(instance);
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
        const value = try XRPoseImpl.get_linearVelocity(instance);
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
        const value = try XRPoseImpl.get_angularVelocity(instance);
        state.cached_angularVelocity = value;
        return value;
    }

    pub fn get_emulatedPosition(instance: *runtime.Instance) anyerror!bool {
        return try XRPoseImpl.get_emulatedPosition(instance);
    }

};
