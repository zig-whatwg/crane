//! Generated from: webxr.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRViewImpl = @import("impls").XRView;
const XRViewGeometry = @import("interfaces").XRViewGeometry;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const Float32Array = @import("interfaces").Float32Array;
const XREye = @import("enums").XREye;
const XRCamera = @import("interfaces").XRCamera;

pub const XRView = struct {
    pub const Meta = struct {
        pub const name = "XRView";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            XRViewGeometry,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            eye: XREye = undefined,
            index: u32 = undefined,
            recommendedViewportScale: ?f64 = null,
            camera: ?XRCamera = null,
            isFirstPersonObserver: bool = undefined,
            projectionMatrix: Float32Array = undefined,
            transform: XRRigidTransform = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRView, .{
        .deinit_fn = &deinit_wrapper,

        .get_camera = &get_camera,
        .get_eye = &get_eye,
        .get_index = &get_index,
        .get_isFirstPersonObserver = &get_isFirstPersonObserver,
        .get_projectionMatrix = &get_projectionMatrix,
        .get_recommendedViewportScale = &get_recommendedViewportScale,
        .get_transform = &get_transform,

        .call_requestViewportScale = &call_requestViewportScale,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return XRViewImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRViewImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_eye(instance: *runtime.Instance) anyerror!XREye {
        return try XRViewImpl.get_eye(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!u32 {
        return try XRViewImpl.get_index(instance);
    }

    pub fn get_recommendedViewportScale(instance: *runtime.Instance) anyerror!f64 {
        return try XRViewImpl.get_recommendedViewportScale(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_camera(instance: *runtime.Instance) anyerror!XRCamera {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_camera) |cached| {
            return cached;
        }
        const value = try XRViewImpl.get_camera(instance);
        state.cached_camera = value;
        return value;
    }

    pub fn get_isFirstPersonObserver(instance: *runtime.Instance) anyerror!bool {
        return try XRViewImpl.get_isFirstPersonObserver(instance);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRViewImpl.get_projectionMatrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = try XRViewImpl.get_transform(instance);
        state.cached_transform = value;
        return value;
    }

    pub fn call_requestViewportScale(instance: *runtime.Instance, scale: f64) anyerror!void {
        
        return try XRViewImpl.call_requestViewportScale(instance, scale);
    }

};
