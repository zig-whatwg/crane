//! Generated from: webxr.idl
//! Generated at: 2025-11-25T13:07:13Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRLayer;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "antialias", "get_antialias", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "framebuffer", "get_framebuffer", null },
            .{ "framebufferWidth", "get_framebufferWidth", null },
            .{ "framebufferHeight", "get_framebufferHeight", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getViewport", "call_getViewport", 1 },
            .{ "getNativeFramebufferScaleFactor", "call_getNativeFramebufferScaleFactor", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getViewport",
            "getNativeFramebufferScaleFactor",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "antialias", "get_antialias", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "framebuffer", "get_framebuffer", null },
            .{ "framebufferWidth", "get_framebufferWidth", null },
            .{ "framebufferHeight", "get_framebufferHeight", null },
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
            antialias: bool = undefined,
            ignoreDepthValues: bool = undefined,
            fixedFoveation: ?f32 = null,
            framebuffer: ?*runtime.Instance = null,
            framebufferWidth: u32 = undefined,
            framebufferHeight: u32 = undefined,
            cached_framebuffer: ?*runtime.Instance = null,
            _internal: ?*XRWebGLLayerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_antialias = &get_antialias,
        .get_fixedFoveation = &get_fixedFoveation,
        .get_framebuffer = &get_framebuffer,
        .get_framebufferHeight = &get_framebufferHeight,
        .get_framebufferWidth = &get_framebufferWidth,
        .get_ignoreDepthValues = &get_ignoreDepthValues,

        .set_fixedFoveation = &set_fixedFoveation,

        .call_getNativeFramebufferScaleFactor = &call_getNativeFramebufferScaleFactor,
        .call_getViewport = &call_getViewport,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRWebGLLayerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRWebGLLayerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, session: *runtime.Instance, context: XRWebGLRenderingContext, layerInit: XRWebGLLayerInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRWebGLLayerImpl.call_constructor(allocator, ctx, session, context, layerInit);
    }

    pub fn get_antialias(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLLayerImpl.get_antialias(instance);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLLayerImpl.get_ignoreDepthValues(instance);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyerror!?f32 {
        return try XRWebGLLayerImpl.get_fixedFoveation(instance);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRWebGLLayerImpl.set_fixedFoveation(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_framebuffer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_framebuffer) |cached| {
            return cached;
        }
        const value = try XRWebGLLayerImpl.get_framebuffer(instance);
        state.own.cached_framebuffer = value;
        return value;
    }

    pub fn get_framebufferWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLLayerImpl.get_framebufferWidth(instance);
    }

    pub fn get_framebufferHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLLayerImpl.get_framebufferHeight(instance);
    }

    pub fn call_getNativeFramebufferScaleFactor(instance: *runtime.Instance, session: *runtime.Instance) anyerror!f64 {
        
        return try XRWebGLLayerImpl.call_getNativeFramebufferScaleFactor(instance, session);
    }

    pub fn call_getViewport(instance: *runtime.Instance, view: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRWebGLLayerImpl.call_getViewport(instance, view);
    }

};
