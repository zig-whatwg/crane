//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRigidTransformImpl = @import("impls").XRRigidTransform;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const Float32Array = @import("interfaces").Float32Array;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

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
        
        // Initialize the instance (Impl receives full instance)
        XRRigidTransformImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRRigidTransformImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, position: DOMPointInit, orientation: DOMPointInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XRRigidTransformImpl.constructor(instance, position, orientation);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_position(instance: *runtime.Instance) anyerror!DOMPointReadOnly {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_position) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_position(instance);
        state.cached_position = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyerror!DOMPointReadOnly {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_orientation) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_orientation(instance);
        state.cached_orientation = value;
        return value;
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRRigidTransformImpl.get_matrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_inverse(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_inverse) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_inverse(instance);
        state.cached_inverse = value;
        return value;
    }

};
