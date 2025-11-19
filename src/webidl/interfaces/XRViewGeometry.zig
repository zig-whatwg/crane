//! Generated from: webxr.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRViewGeometryImpl = @import("impls").XRViewGeometry;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const Float32Array = @import("interfaces").Float32Array;

pub const XRViewGeometry = struct {
    pub const Meta = struct {
        pub const name = "XRViewGeometry";
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
            projectionMatrix: Float32Array = undefined,
            transform: XRRigidTransform = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRViewGeometry, .{
        .deinit_fn = &deinit_wrapper,

        .get_projectionMatrix = &get_projectionMatrix,
        .get_transform = &get_transform,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return XRViewGeometryImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRViewGeometryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRViewGeometryImpl.get_projectionMatrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = try XRViewGeometryImpl.get_transform(instance);
        state.cached_transform = value;
        return value;
    }

};
