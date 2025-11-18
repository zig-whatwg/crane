//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLBindingImpl = @import("../impls/XRWebGLBinding.zig");

pub const XRWebGLBinding = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLBinding";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            nativeProjectionScaleFactor: f64 = undefined,
            usesDepthValues: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRWebGLBinding, .{
        .deinit_fn = &deinit_wrapper,

        .get_nativeProjectionScaleFactor = &get_nativeProjectionScaleFactor,
        .get_usesDepthValues = &get_usesDepthValues,

        .call_createCubeLayer = &call_createCubeLayer,
        .call_createCylinderLayer = &call_createCylinderLayer,
        .call_createEquirectLayer = &call_createEquirectLayer,
        .call_createProjectionLayer = &call_createProjectionLayer,
        .call_createQuadLayer = &call_createQuadLayer,
        .call_foveateBoundTexture = &call_foveateBoundTexture,
        .call_getCameraImage = &call_getCameraImage,
        .call_getDepthInformation = &call_getDepthInformation,
        .call_getReflectionCubeMap = &call_getReflectionCubeMap,
        .call_getSubImage = &call_getSubImage,
        .call_getViewSubImage = &call_getViewSubImage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRWebGLBindingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRWebGLBindingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, session: anyopaque, context: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try XRWebGLBindingImpl.constructor(state, session, context);
        
        return instance;
    }

    pub fn get_nativeProjectionScaleFactor(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return XRWebGLBindingImpl.get_nativeProjectionScaleFactor(state);
    }

    pub fn get_usesDepthValues(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRWebGLBindingImpl.get_usesDepthValues(state);
    }

    pub fn call_getCameraImage(instance: *runtime.Instance, camera: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_getCameraImage(state, camera);
    }

    pub fn call_createCylinderLayer(instance: *runtime.Instance, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_createCylinderLayer(state, init);
    }

    pub fn call_createCubeLayer(instance: *runtime.Instance, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_createCubeLayer(state, init);
    }

    pub fn call_createQuadLayer(instance: *runtime.Instance, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_createQuadLayer(state, init);
    }

    pub fn call_getSubImage(instance: *runtime.Instance, layer: anyopaque, frame: anyopaque, eye: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_getSubImage(state, layer, frame, eye);
    }

    pub fn call_getViewSubImage(instance: *runtime.Instance, layer: anyopaque, view: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_getViewSubImage(state, layer, view);
    }

    pub fn call_getReflectionCubeMap(instance: *runtime.Instance, lightProbe: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_getReflectionCubeMap(state, lightProbe);
    }

    pub fn call_createProjectionLayer(instance: *runtime.Instance, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_createProjectionLayer(state, init);
    }

    pub fn call_createEquirectLayer(instance: *runtime.Instance, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_createEquirectLayer(state, init);
    }

    pub fn call_foveateBoundTexture(instance: *runtime.Instance, target: anyopaque, fixed_foveation: f32) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_foveateBoundTexture(state, target, fixed_foveation);
    }

    pub fn call_getDepthInformation(instance: *runtime.Instance, view: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLBindingImpl.call_getDepthInformation(state, view);
    }

};
