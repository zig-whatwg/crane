//! Generated from: webxr.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLLayerImpl = @import("impls").XRWebGLLayer;
const XRLayer = @import("interfaces").XRLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const XRView = @import("interfaces").XRView;
const XRSession = @import("interfaces").XRSession;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const XRViewport = @import("interfaces").XRViewport;
const WebGLFramebuffer = @import("interfaces").WebGLFramebuffer;
const XRWebGLLayerInit = @import("dictionaries").XRWebGLLayerInit;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const XRWebGLRenderingContext = @import("typedefs").XRWebGLRenderingContext;
const DOMString = @import("typedefs").DOMString;

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
        return XRWebGLLayerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRWebGLLayerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, session: XRSession, context: XRWebGLRenderingContext, layerInit: XRWebGLLayerInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XRWebGLLayerImpl.constructor(instance, session, context, layerInit);
        
        return instance;
    }

    pub fn get_antialias(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLLayerImpl.get_antialias(instance);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLLayerImpl.get_ignoreDepthValues(instance);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyerror!f32 {
        return try XRWebGLLayerImpl.get_fixedFoveation(instance);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRWebGLLayerImpl.set_fixedFoveation(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_framebuffer(instance: *runtime.Instance) anyerror!WebGLFramebuffer {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_framebuffer) |cached| {
            return cached;
        }
        const value = try XRWebGLLayerImpl.get_framebuffer(instance);
        state.cached_framebuffer = value;
        return value;
    }

    pub fn get_framebufferWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLLayerImpl.get_framebufferWidth(instance);
    }

    pub fn get_framebufferHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLLayerImpl.get_framebufferHeight(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRWebGLLayerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getViewport(instance: *runtime.Instance, view: XRView) anyerror!XRViewport {
        
        return try XRWebGLLayerImpl.call_getViewport(instance, view);
    }

    pub fn call_getNativeFramebufferScaleFactor(instance: *runtime.Instance, session: XRSession) anyerror!f64 {
        
        return try XRWebGLLayerImpl.call_getNativeFramebufferScaleFactor(instance, session);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRWebGLLayerImpl.call_when(instance, @"type", options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try XRWebGLLayerImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try XRWebGLLayerImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
