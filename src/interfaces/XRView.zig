//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRViewImpl = @import("../impls/XRView.zig");
const XRViewGeometry = @import("XRViewGeometry.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRViewImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRViewImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_eye(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRViewImpl.get_eye(state);
    }

    pub fn get_index(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRViewImpl.get_index(state);
    }

    pub fn get_recommendedViewportScale(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRViewImpl.get_recommendedViewportScale(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_camera(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_camera) |cached| {
            return cached;
        }
        const value = XRViewImpl.get_camera(state);
        state.cached_camera = value;
        return value;
    }

    pub fn get_isFirstPersonObserver(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRViewImpl.get_isFirstPersonObserver(state);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRViewImpl.get_projectionMatrix(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = XRViewImpl.get_transform(state);
        state.cached_transform = value;
        return value;
    }

    pub fn call_requestViewportScale(instance: *runtime.Instance, scale: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRViewImpl.call_requestViewportScale(state, scale);
    }

};
