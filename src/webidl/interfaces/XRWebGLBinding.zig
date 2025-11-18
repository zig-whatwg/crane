//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLBindingImpl = @import("impls").XRWebGLBinding;
const XREquirectLayer = @import("interfaces").XREquirectLayer;
const XRCubeLayer = @import("interfaces").XRCubeLayer;
const XREquirectLayerInit = @import("dictionaries").XREquirectLayerInit;
const XRView = @import("interfaces").XRView;
const XRFrame = @import("interfaces").XRFrame;
const XRCylinderLayer = @import("interfaces").XRCylinderLayer;
const XRWebGLSubImage = @import("interfaces").XRWebGLSubImage;
const XRCamera = @import("interfaces").XRCamera;
const XRSession = @import("interfaces").XRSession;
const XRQuadLayer = @import("interfaces").XRQuadLayer;
const XRCubeLayerInit = @import("dictionaries").XRCubeLayerInit;
const XRWebGLDepthInformation = @import("interfaces").XRWebGLDepthInformation;
const GLenum = @import("typedefs").GLenum;
const XRQuadLayerInit = @import("dictionaries").XRQuadLayerInit;
const XRCylinderLayerInit = @import("dictionaries").XRCylinderLayerInit;
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const XRLightProbe = @import("interfaces").XRLightProbe;
const XRWebGLRenderingContext = @import("typedefs").XRWebGLRenderingContext;
const XRProjectionLayer = @import("interfaces").XRProjectionLayer;
const XRProjectionLayerInit = @import("dictionaries").XRProjectionLayerInit;
const XREye = @import("enums").XREye;
const WebGLTexture = @import("interfaces").WebGLTexture;

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
        
        // Initialize the instance (Impl receives full instance)
        XRWebGLBindingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRWebGLBindingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, session: XRSession, context: XRWebGLRenderingContext) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XRWebGLBindingImpl.constructor(instance, session, context);
        
        return instance;
    }

    pub fn get_nativeProjectionScaleFactor(instance: *runtime.Instance) anyerror!f64 {
        return try XRWebGLBindingImpl.get_nativeProjectionScaleFactor(instance);
    }

    pub fn get_usesDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLBindingImpl.get_usesDepthValues(instance);
    }

    pub fn call_getCameraImage(instance: *runtime.Instance, camera: XRCamera) anyerror!anyopaque {
        
        return try XRWebGLBindingImpl.call_getCameraImage(instance, camera);
    }

    pub fn call_createCylinderLayer(instance: *runtime.Instance, init: XRCylinderLayerInit) anyerror!XRCylinderLayer {
        
        return try XRWebGLBindingImpl.call_createCylinderLayer(instance, init);
    }

    pub fn call_createCubeLayer(instance: *runtime.Instance, init: XRCubeLayerInit) anyerror!XRCubeLayer {
        
        return try XRWebGLBindingImpl.call_createCubeLayer(instance, init);
    }

    pub fn call_createQuadLayer(instance: *runtime.Instance, init: XRQuadLayerInit) anyerror!XRQuadLayer {
        
        return try XRWebGLBindingImpl.call_createQuadLayer(instance, init);
    }

    pub fn call_getSubImage(instance: *runtime.Instance, layer: XRCompositionLayer, frame: XRFrame, eye: XREye) anyerror!XRWebGLSubImage {
        
        return try XRWebGLBindingImpl.call_getSubImage(instance, layer, frame, eye);
    }

    pub fn call_getViewSubImage(instance: *runtime.Instance, layer: XRProjectionLayer, view: XRView) anyerror!XRWebGLSubImage {
        
        return try XRWebGLBindingImpl.call_getViewSubImage(instance, layer, view);
    }

    pub fn call_getReflectionCubeMap(instance: *runtime.Instance, lightProbe: XRLightProbe) anyerror!anyopaque {
        
        return try XRWebGLBindingImpl.call_getReflectionCubeMap(instance, lightProbe);
    }

    pub fn call_createProjectionLayer(instance: *runtime.Instance, init: XRProjectionLayerInit) anyerror!XRProjectionLayer {
        
        return try XRWebGLBindingImpl.call_createProjectionLayer(instance, init);
    }

    pub fn call_createEquirectLayer(instance: *runtime.Instance, init: XREquirectLayerInit) anyerror!XREquirectLayer {
        
        return try XRWebGLBindingImpl.call_createEquirectLayer(instance, init);
    }

    pub fn call_foveateBoundTexture(instance: *runtime.Instance, target: GLenum, fixed_foveation: f32) anyerror!void {
        
        return try XRWebGLBindingImpl.call_foveateBoundTexture(instance, target, fixed_foveation);
    }

    pub fn call_getDepthInformation(instance: *runtime.Instance, view: XRView) anyerror!anyopaque {
        
        return try XRWebGLBindingImpl.call_getDepthInformation(instance, view);
    }

};
