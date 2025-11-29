//! Generated from: webxr.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRViewImpl = @import("impls").XRView;
const mixins = @import("mixins");
const XRViewGeometry = @import("interfaces").XRViewGeometry;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XREye = @import("enums").XREye;
const XRCamera = @import("interfaces").XRCamera;

pub const XRView = struct {
    pub const Meta = struct {
        pub const name = "XRView";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            XRViewGeometry,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "recommendedViewportScale", "get_recommendedViewportScale", null },
            .{ "camera", "get_camera", null },
            .{ "isFirstPersonObserver", "get_isFirstPersonObserver", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestViewportScale", "call_requestViewportScale", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestViewportScale",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "recommendedViewportScale", "get_recommendedViewportScale", null },
            .{ "camera", "get_camera", null },
            .{ "isFirstPersonObserver", "get_isFirstPersonObserver", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            eye: XREye = undefined,
            index: u32 = undefined,
            recommendedViewportScale: ?f64 = null,
            camera: ?*runtime.Instance = null,
            isFirstPersonObserver: bool = undefined,
            projectionMatrix: runtime.Float32Array = undefined,
            transform: *runtime.Instance = undefined,
            cached_camera: ?*runtime.Instance = null,
            cached_transform: ?*runtime.Instance = null,
            _internal: ?*XRViewImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_camera = &get_camera,
        .get_eye = &get_eye,
        .get_index = &get_index,
        .get_isFirstPersonObserver = &get_isFirstPersonObserver,
        .get_projectionMatrix = &get_projectionMatrix,
        .get_recommendedViewportScale = &get_recommendedViewportScale,
        .get_transform = &get_transform,

        .call_requestViewportScale = &call_requestViewportScale,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRViewImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRViewImpl.deinit(instance);
    }

    pub fn get_eye(instance: *runtime.Instance) anyerror!XREye {
        return try XRViewImpl.get_eye(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!u32 {
        return try XRViewImpl.get_index(instance);
    }

    pub fn get_recommendedViewportScale(instance: *runtime.Instance) anyerror!?f64 {
        return try XRViewImpl.get_recommendedViewportScale(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_camera(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_camera) |cached| {
            return cached;
        }
        const value = try XRViewImpl.get_camera(instance);
        state.own.cached_camera = value;
        return value;
    }

    pub fn get_isFirstPersonObserver(instance: *runtime.Instance) anyerror!bool {
        return try XRViewImpl.get_isFirstPersonObserver(instance);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRViewImpl.get_projectionMatrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transform) |cached| {
            return cached;
        }
        const value = try XRViewImpl.get_transform(instance);
        state.own.cached_transform = value;
        return value;
    }

    pub fn call_requestViewportScale(instance: *runtime.Instance, scale: ?f64) anyerror!void {
        
        return try XRViewImpl.call_requestViewportScale(instance, scale);
    }

};
