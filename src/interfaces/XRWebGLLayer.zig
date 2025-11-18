//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLLayerImpl = @import("../impls/XRWebGLLayer.zig");
const XRLayer = @import("XRLayer.zig");

pub const XRWebGLLayer = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLLayer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRLayer;
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
            antialias: bool = undefined,
            ignoreDepthValues: bool = undefined,
            fixedFoveation: ?f32 = null,
            framebuffer: ?WebGLFramebuffer = null,
            framebufferWidth: u32 = undefined,
            framebufferHeight: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRWebGLLayer, .{
        .deinit_fn = &deinit_wrapper,

        .get_antialias = &get_antialias,
        .get_fixedFoveation = &get_fixedFoveation,
        .get_framebuffer = &get_framebuffer,
        .get_framebufferHeight = &get_framebufferHeight,
        .get_framebufferWidth = &get_framebufferWidth,
        .get_ignoreDepthValues = &get_ignoreDepthValues,

        .set_fixedFoveation = &set_fixedFoveation,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getNativeFramebufferScaleFactor = &call_getNativeFramebufferScaleFactor,
        .call_getViewport = &call_getViewport,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRWebGLLayerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRWebGLLayerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, session: anyopaque, context: anyopaque, layerInit: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try XRWebGLLayerImpl.constructor(state, session, context, layerInit);
        
        return instance;
    }

    pub fn get_antialias(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRWebGLLayerImpl.get_antialias(state);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRWebGLLayerImpl.get_ignoreDepthValues(state);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLLayerImpl.get_fixedFoveation(state);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRWebGLLayerImpl.set_fixedFoveation(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_framebuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_framebuffer) |cached| {
            return cached;
        }
        const value = XRWebGLLayerImpl.get_framebuffer(state);
        state.cached_framebuffer = value;
        return value;
    }

    pub fn get_framebufferWidth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRWebGLLayerImpl.get_framebufferWidth(state);
    }

    pub fn get_framebufferHeight(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRWebGLLayerImpl.get_framebufferHeight(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRWebGLLayerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getViewport(instance: *runtime.Instance, view: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLLayerImpl.call_getViewport(state, view);
    }

    pub fn call_getNativeFramebufferScaleFactor(instance: *runtime.Instance, session: anyopaque) f64 {
        const state = instance.getState(State);
        
        return XRWebGLLayerImpl.call_getNativeFramebufferScaleFactor(state, session);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLLayerImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLLayerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRWebGLLayerImpl.call_removeEventListener(state, type_, callback, options);
    }

};
