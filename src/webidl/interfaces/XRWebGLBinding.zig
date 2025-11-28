//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-28T03:24:37Z
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
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "nativeProjectionScaleFactor", "get_nativeProjectionScaleFactor", null },
            .{ "usesDepthValues", "get_usesDepthValues", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createProjectionLayer", "call_createProjectionLayer", 0 },
            .{ "createQuadLayer", "call_createQuadLayer", 0 },
            .{ "createCylinderLayer", "call_createCylinderLayer", 0 },
            .{ "createEquirectLayer", "call_createEquirectLayer", 0 },
            .{ "createCubeLayer", "call_createCubeLayer", 0 },
            .{ "getSubImage", "call_getSubImage", 2 },
            .{ "getViewSubImage", "call_getViewSubImage", 2 },
            .{ "foveateBoundTexture", "call_foveateBoundTexture", 2 },
            .{ "getCameraImage", "call_getCameraImage", 1 },
            .{ "getDepthInformation", "call_getDepthInformation", 1 },
            .{ "getReflectionCubeMap", "call_getReflectionCubeMap", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createProjectionLayer",
            "createQuadLayer",
            "createCylinderLayer",
            "createEquirectLayer",
            "createCubeLayer",
            "getSubImage",
            "getViewSubImage",
            "foveateBoundTexture",
            "getCameraImage",
            "getDepthInformation",
            "getReflectionCubeMap",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "nativeProjectionScaleFactor", "get_nativeProjectionScaleFactor", null },
            .{ "usesDepthValues", "get_usesDepthValues", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            nativeProjectionScaleFactor: f64 = undefined,
            usesDepthValues: bool = undefined,
            _internal: ?*XRWebGLBindingImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRWebGLBindingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRWebGLBindingImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, session: *runtime.Instance, context: XRWebGLRenderingContext) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRWebGLBindingImpl.call_constructor(allocator, ctx, session, context);
    }

    pub fn get_nativeProjectionScaleFactor(instance: *runtime.Instance) anyerror!f64 {
        return try XRWebGLBindingImpl.get_nativeProjectionScaleFactor(instance);
    }

    pub fn get_usesDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLBindingImpl.get_usesDepthValues(instance);
    }

    pub fn call_getCameraImage(instance: *runtime.Instance, camera: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_getCameraImage(instance, camera);
    }

    pub fn call_createCylinderLayer(instance: *runtime.Instance, init_data: XRCylinderLayerInit) anyerror!*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_createCylinderLayer(instance, init_data);
    }

    pub fn call_createCubeLayer(instance: *runtime.Instance, init_data: XRCubeLayerInit) anyerror!*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_createCubeLayer(instance, init_data);
    }

    pub fn call_createQuadLayer(instance: *runtime.Instance, init_data: XRQuadLayerInit) anyerror!*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_createQuadLayer(instance, init_data);
    }

    pub fn call_getSubImage(instance: *runtime.Instance, layer: *runtime.Instance, frame: *runtime.Instance, eye: XREye) anyerror!*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_getSubImage(instance, layer, frame, eye);
    }

    pub fn call_getViewSubImage(instance: *runtime.Instance, layer: *runtime.Instance, view: *runtime.Instance) anyerror!*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_getViewSubImage(instance, layer, view);
    }

    pub fn call_getReflectionCubeMap(instance: *runtime.Instance, lightProbe: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_getReflectionCubeMap(instance, lightProbe);
    }

    pub fn call_createProjectionLayer(instance: *runtime.Instance, init_data: XRProjectionLayerInit) anyerror!*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_createProjectionLayer(instance, init_data);
    }

    pub fn call_createEquirectLayer(instance: *runtime.Instance, init_data: XREquirectLayerInit) anyerror!*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_createEquirectLayer(instance, init_data);
    }

    pub fn call_foveateBoundTexture(instance: *runtime.Instance, target: GLenum, fixed_foveation: f32) anyerror!void {
        
        return try XRWebGLBindingImpl.call_foveateBoundTexture(instance, target, fixed_foveation);
    }

    pub fn call_getDepthInformation(instance: *runtime.Instance, view: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRWebGLBindingImpl.call_getDepthInformation(instance, view);
    }

};
