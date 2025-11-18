//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRigidTransformImpl = @import("../impls/XRRigidTransform.zig");

pub const XRRigidTransform = struct {
    pub const Meta = struct {
        pub const name = "XRRigidTransform";
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
            position: DOMPointReadOnly = undefined,
            orientation: DOMPointReadOnly = undefined,
            matrix: Float32Array = undefined,
            inverse: XRRigidTransform = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRRigidTransform, .{
        .deinit_fn = &deinit_wrapper,

        .get_inverse = &get_inverse,
        .get_matrix = &get_matrix,
        .get_orientation = &get_orientation,
        .get_position = &get_position,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRRigidTransformImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRRigidTransformImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, position: anyopaque, orientation: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try XRRigidTransformImpl.constructor(state, position, orientation);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_position(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_position) |cached| {
            return cached;
        }
        const value = XRRigidTransformImpl.get_position(state);
        state.cached_position = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_orientation) |cached| {
            return cached;
        }
        const value = XRRigidTransformImpl.get_orientation(state);
        state.cached_orientation = value;
        return value;
    }

    pub fn get_matrix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRRigidTransformImpl.get_matrix(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_inverse(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_inverse) |cached| {
            return cached;
        }
        const value = XRRigidTransformImpl.get_inverse(state);
        state.cached_inverse = value;
        return value;
    }

};
