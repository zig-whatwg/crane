//! Generated from: webxr.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRSessionImpl = @import("impls").XRSession;
const EventTarget = @import("interfaces").EventTarget;
const XRTransientInputHitTestSource = @import("interfaces").XRTransientInputHitTestSource;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const XRHitTestSource = @import("interfaces").XRHitTestSource;
const XRDepthDataFormat = @import("enums").XRDepthDataFormat;
const XRDOMOverlayState = @import("dictionaries").XRDOMOverlayState;
const XRFrameRequestCallback = @import("callbacks").XRFrameRequestCallback;
const XRRenderStateInit = @import("dictionaries").XRRenderStateInit;
const XRDepthUsage = @import("enums").XRDepthUsage;
const XREnvironmentBlendMode = @import("enums").XREnvironmentBlendMode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRVisibilityState = @import("enums").XRVisibilityState;
const XRInputSourceArray = @import("interfaces").XRInputSourceArray;
const XRAnchor = @import("interfaces").XRAnchor;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const XRHitTestOptionsInit = @import("dictionaries").XRHitTestOptionsInit;
const XRReferenceSpaceType = @import("enums").XRReferenceSpaceType;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const XRTransientInputHitTestOptionsInit = @import("dictionaries").XRTransientInputHitTestOptionsInit;
const XRReferenceSpace = @import("interfaces").XRReferenceSpace;
const XRLightProbeInit = @import("dictionaries").XRLightProbeInit;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const XRDepthType = @import("enums").XRDepthType;
const XRRenderState = @import("interfaces").XRRenderState;
const XRReflectionFormat = @import("enums").XRReflectionFormat;
const XRLightProbe = @import("interfaces").XRLightProbe;
const XRInteractionMode = @import("enums").XRInteractionMode;
const DOMString = @import("typedefs").DOMString;

pub const XRSession = struct {
    pub const Meta = struct {
        pub const name = "XRSession";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "visibilityState", "get_visibilityState", null },
            .{ "frameRate", "get_frameRate", null },
            .{ "supportedFrameRates", "get_supportedFrameRates", null },
            .{ "renderState", "get_renderState", null },
            .{ "inputSources", "get_inputSources", null },
            .{ "trackedSources", "get_trackedSources", null },
            .{ "enabledFeatures", "get_enabledFeatures", null },
            .{ "isSystemKeyboardSupported", "get_isSystemKeyboardSupported", null },
            .{ "onend", "get_onend", "set_onend" },
            .{ "oninputsourceschange", "get_oninputsourceschange", "set_oninputsourceschange" },
            .{ "onselect", "get_onselect", "set_onselect" },
            .{ "onselectstart", "get_onselectstart", "set_onselectstart" },
            .{ "onselectend", "get_onselectend", "set_onselectend" },
            .{ "onsqueeze", "get_onsqueeze", "set_onsqueeze" },
            .{ "onsqueezestart", "get_onsqueezestart", "set_onsqueezestart" },
            .{ "onsqueezeend", "get_onsqueezeend", "set_onsqueezeend" },
            .{ "onvisibilitychange", "get_onvisibilitychange", "set_onvisibilitychange" },
            .{ "onframeratechange", "get_onframeratechange", "set_onframeratechange" },
            .{ "domOverlayState", "get_domOverlayState", null },
            .{ "depthUsage", "get_depthUsage", null },
            .{ "depthDataFormat", "get_depthDataFormat", null },
            .{ "depthType", "get_depthType", null },
            .{ "depthActive", "get_depthActive", null },
            .{ "persistentAnchors", "get_persistentAnchors", null },
            .{ "preferredReflectionFormat", "get_preferredReflectionFormat", null },
            .{ "environmentBlendMode", "get_environmentBlendMode", null },
            .{ "interactionMode", "get_interactionMode", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "updateRenderState", "call_updateRenderState", 0 },
            .{ "updateTargetFrameRate", "call_updateTargetFrameRate", 1 },
            .{ "requestReferenceSpace", "call_requestReferenceSpace", 1 },
            .{ "requestAnimationFrame", "call_requestAnimationFrame", 1 },
            .{ "cancelAnimationFrame", "call_cancelAnimationFrame", 1 },
            .{ "end", "call_end", 0 },
            .{ "requestHitTestSource", "call_requestHitTestSource", 1 },
            .{ "requestHitTestSourceForTransientInput", "call_requestHitTestSourceForTransientInput", 1 },
            .{ "pauseDepthSensing", "call_pauseDepthSensing", 0 },
            .{ "resumeDepthSensing", "call_resumeDepthSensing", 0 },
            .{ "restorePersistentAnchor", "call_restorePersistentAnchor", 1 },
            .{ "deletePersistentAnchor", "call_deletePersistentAnchor", 1 },
            .{ "requestLightProbe", "call_requestLightProbe", 0 },
            .{ "initiateRoomCapture", "call_initiateRoomCapture", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "updateRenderState",
            "updateTargetFrameRate",
            "requestReferenceSpace",
            "requestAnimationFrame",
            "cancelAnimationFrame",
            "end",
            "requestHitTestSource",
            "requestHitTestSourceForTransientInput",
            "pauseDepthSensing",
            "resumeDepthSensing",
            "restorePersistentAnchor",
            "deletePersistentAnchor",
            "requestLightProbe",
            "initiateRoomCapture",
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
            .{ "visibilityState", "get_visibilityState", null },
            .{ "frameRate", "get_frameRate", null },
            .{ "supportedFrameRates", "get_supportedFrameRates", null },
            .{ "renderState", "get_renderState", null },
            .{ "inputSources", "get_inputSources", null },
            .{ "trackedSources", "get_trackedSources", null },
            .{ "enabledFeatures", "get_enabledFeatures", null },
            .{ "isSystemKeyboardSupported", "get_isSystemKeyboardSupported", null },
            .{ "onend", "get_onend", "set_onend" },
            .{ "oninputsourceschange", "get_oninputsourceschange", "set_oninputsourceschange" },
            .{ "onselect", "get_onselect", "set_onselect" },
            .{ "onselectstart", "get_onselectstart", "set_onselectstart" },
            .{ "onselectend", "get_onselectend", "set_onselectend" },
            .{ "onsqueeze", "get_onsqueeze", "set_onsqueeze" },
            .{ "onsqueezestart", "get_onsqueezestart", "set_onsqueezestart" },
            .{ "onsqueezeend", "get_onsqueezeend", "set_onsqueezeend" },
            .{ "onvisibilitychange", "get_onvisibilitychange", "set_onvisibilitychange" },
            .{ "onframeratechange", "get_onframeratechange", "set_onframeratechange" },
            .{ "domOverlayState", "get_domOverlayState", null },
            .{ "depthUsage", "get_depthUsage", null },
            .{ "depthDataFormat", "get_depthDataFormat", null },
            .{ "depthType", "get_depthType", null },
            .{ "depthActive", "get_depthActive", null },
            .{ "persistentAnchors", "get_persistentAnchors", null },
            .{ "preferredReflectionFormat", "get_preferredReflectionFormat", null },
            .{ "environmentBlendMode", "get_environmentBlendMode", null },
            .{ "interactionMode", "get_interactionMode", null },
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
            visibilityState: XRVisibilityState = undefined,
            frameRate: ?f32 = null,
            supportedFrameRates: ?runtime.Float32Array = null,
            renderState: XRRenderState = undefined,
            inputSources: XRInputSourceArray = undefined,
            trackedSources: XRInputSourceArray = undefined,
            enabledFeatures: runtime.FrozenArray(runtime.DOMString) = undefined,
            isSystemKeyboardSupported: bool = undefined,
            onend: EventHandler = undefined,
            oninputsourceschange: EventHandler = undefined,
            onselect: EventHandler = undefined,
            onselectstart: EventHandler = undefined,
            onselectend: EventHandler = undefined,
            onsqueeze: EventHandler = undefined,
            onsqueezestart: EventHandler = undefined,
            onsqueezeend: EventHandler = undefined,
            onvisibilitychange: EventHandler = undefined,
            onframeratechange: EventHandler = undefined,
            domOverlayState: ?XRDOMOverlayState = null,
            depthUsage: XRDepthUsage = undefined,
            depthDataFormat: XRDepthDataFormat = undefined,
            depthType: ?XRDepthType = null,
            depthActive: ?bool = null,
            persistentAnchors: runtime.FrozenArray(runtime.DOMString) = undefined,
            preferredReflectionFormat: XRReflectionFormat = undefined,
            environmentBlendMode: XREnvironmentBlendMode = undefined,
            interactionMode: XRInteractionMode = undefined,
            cached_renderState: ?XRRenderState = null,
            cached_inputSources: ?XRInputSourceArray = null,
            cached_trackedSources: ?XRInputSourceArray = null,
        },
    );

    const delegates = .{

        .get_depthActive = &get_depthActive,
        .get_depthDataFormat = &get_depthDataFormat,
        .get_depthType = &get_depthType,
        .get_depthUsage = &get_depthUsage,
        .get_domOverlayState = &get_domOverlayState,
        .get_enabledFeatures = &get_enabledFeatures,
        .get_environmentBlendMode = &get_environmentBlendMode,
        .get_frameRate = &get_frameRate,
        .get_inputSources = &get_inputSources,
        .get_interactionMode = &get_interactionMode,
        .get_isSystemKeyboardSupported = &get_isSystemKeyboardSupported,
        .get_onend = &get_onend,
        .get_onframeratechange = &get_onframeratechange,
        .get_oninputsourceschange = &get_oninputsourceschange,
        .get_onselect = &get_onselect,
        .get_onselectend = &get_onselectend,
        .get_onselectstart = &get_onselectstart,
        .get_onsqueeze = &get_onsqueeze,
        .get_onsqueezeend = &get_onsqueezeend,
        .get_onsqueezestart = &get_onsqueezestart,
        .get_onvisibilitychange = &get_onvisibilitychange,
        .get_persistentAnchors = &get_persistentAnchors,
        .get_preferredReflectionFormat = &get_preferredReflectionFormat,
        .get_renderState = &get_renderState,
        .get_supportedFrameRates = &get_supportedFrameRates,
        .get_trackedSources = &get_trackedSources,
        .get_visibilityState = &get_visibilityState,

        .set_onend = &set_onend,
        .set_onframeratechange = &set_onframeratechange,
        .set_oninputsourceschange = &set_oninputsourceschange,
        .set_onselect = &set_onselect,
        .set_onselectend = &set_onselectend,
        .set_onselectstart = &set_onselectstart,
        .set_onsqueeze = &set_onsqueeze,
        .set_onsqueezeend = &set_onsqueezeend,
        .set_onsqueezestart = &set_onsqueezestart,
        .set_onvisibilitychange = &set_onvisibilitychange,

        .call_cancelAnimationFrame = &call_cancelAnimationFrame,
        .call_deletePersistentAnchor = &call_deletePersistentAnchor,
        .call_end = &call_end,
        .call_initiateRoomCapture = &call_initiateRoomCapture,
        .call_pauseDepthSensing = &call_pauseDepthSensing,
        .call_requestAnimationFrame = &call_requestAnimationFrame,
        .call_requestHitTestSource = &call_requestHitTestSource,
        .call_requestHitTestSourceForTransientInput = &call_requestHitTestSourceForTransientInput,
        .call_requestLightProbe = &call_requestLightProbe,
        .call_requestReferenceSpace = &call_requestReferenceSpace,
        .call_restorePersistentAnchor = &call_restorePersistentAnchor,
        .call_resumeDepthSensing = &call_resumeDepthSensing,
        .call_updateRenderState = &call_updateRenderState,
        .call_updateTargetFrameRate = &call_updateTargetFrameRate,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRSessionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRSessionImpl.deinit(instance);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyerror!XRVisibilityState {
        return try XRSessionImpl.get_visibilityState(instance);
    }

    pub fn get_frameRate(instance: *runtime.Instance) anyerror!f32 {
        return try XRSessionImpl.get_frameRate(instance);
    }

    pub fn get_supportedFrameRates(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRSessionImpl.get_supportedFrameRates(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_renderState(instance: *runtime.Instance) anyerror!XRRenderState {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_renderState) |cached| {
            return cached;
        }
        const value = try XRSessionImpl.get_renderState(instance);
        state.own.cached_renderState = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSources(instance: *runtime.Instance) anyerror!XRInputSourceArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_inputSources) |cached| {
            return cached;
        }
        const value = try XRSessionImpl.get_inputSources(instance);
        state.own.cached_inputSources = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_trackedSources(instance: *runtime.Instance) anyerror!XRInputSourceArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_trackedSources) |cached| {
            return cached;
        }
        const value = try XRSessionImpl.get_trackedSources(instance);
        state.own.cached_trackedSources = value;
        return value;
    }

    pub fn get_enabledFeatures(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRSessionImpl.get_enabledFeatures(instance);
    }

    pub fn get_isSystemKeyboardSupported(instance: *runtime.Instance) anyerror!bool {
        return try XRSessionImpl.get_isSystemKeyboardSupported(instance);
    }

    pub fn get_onend(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onend(instance);
    }

    pub fn set_onend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onend(instance, value);
    }

    pub fn get_oninputsourceschange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_oninputsourceschange(instance);
    }

    pub fn set_oninputsourceschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_oninputsourceschange(instance, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onselect(instance);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onselect(instance, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onselectstart(instance);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onselectstart(instance, value);
    }

    pub fn get_onselectend(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onselectend(instance);
    }

    pub fn set_onselectend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onselectend(instance, value);
    }

    pub fn get_onsqueeze(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onsqueeze(instance);
    }

    pub fn set_onsqueeze(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onsqueeze(instance, value);
    }

    pub fn get_onsqueezestart(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onsqueezestart(instance);
    }

    pub fn set_onsqueezestart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onsqueezestart(instance, value);
    }

    pub fn get_onsqueezeend(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onsqueezeend(instance);
    }

    pub fn set_onsqueezeend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onsqueezeend(instance, value);
    }

    pub fn get_onvisibilitychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onvisibilitychange(instance);
    }

    pub fn set_onvisibilitychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onvisibilitychange(instance, value);
    }

    pub fn get_onframeratechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSessionImpl.get_onframeratechange(instance);
    }

    pub fn set_onframeratechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSessionImpl.set_onframeratechange(instance, value);
    }

    pub fn get_domOverlayState(instance: *runtime.Instance) anyerror!XRDOMOverlayState {
        return try XRSessionImpl.get_domOverlayState(instance);
    }

    pub fn get_depthUsage(instance: *runtime.Instance) anyerror!XRDepthUsage {
        return try XRSessionImpl.get_depthUsage(instance);
    }

    pub fn get_depthDataFormat(instance: *runtime.Instance) anyerror!XRDepthDataFormat {
        return try XRSessionImpl.get_depthDataFormat(instance);
    }

    pub fn get_depthType(instance: *runtime.Instance) anyerror!XRDepthType {
        return try XRSessionImpl.get_depthType(instance);
    }

    pub fn get_depthActive(instance: *runtime.Instance) anyerror!bool {
        return try XRSessionImpl.get_depthActive(instance);
    }

    pub fn get_persistentAnchors(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRSessionImpl.get_persistentAnchors(instance);
    }

    pub fn get_preferredReflectionFormat(instance: *runtime.Instance) anyerror!XRReflectionFormat {
        return try XRSessionImpl.get_preferredReflectionFormat(instance);
    }

    pub fn get_environmentBlendMode(instance: *runtime.Instance) anyerror!XREnvironmentBlendMode {
        return try XRSessionImpl.get_environmentBlendMode(instance);
    }

    pub fn get_interactionMode(instance: *runtime.Instance) anyerror!XRInteractionMode {
        return try XRSessionImpl.get_interactionMode(instance);
    }

    pub fn call_deletePersistentAnchor(instance: *runtime.Instance, uuid: DOMString) anyerror!*const anyopaque {
        
        return try XRSessionImpl.call_deletePersistentAnchor(instance, uuid);
    }

    pub fn call_requestHitTestSourceForTransientInput(instance: *runtime.Instance, options: XRTransientInputHitTestOptionsInit) anyerror!*const anyopaque {
        
        return try XRSessionImpl.call_requestHitTestSourceForTransientInput(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestReferenceSpace(instance: *runtime.Instance, @"type": XRReferenceSpaceType) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try XRSessionImpl.call_requestReferenceSpace(instance, @"type");
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
        
        return try XRSessionImpl.call_cancelAnimationFrame(instance, handle);
    }

    pub fn call_requestLightProbe(instance: *runtime.Instance, options: XRLightProbeInit) anyerror!*const anyopaque {
        
        return try XRSessionImpl.call_requestLightProbe(instance, options);
    }

    pub fn call_end(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRSessionImpl.call_end(instance);
    }

    pub fn call_initiateRoomCapture(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRSessionImpl.call_initiateRoomCapture(instance);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: XRFrameRequestCallback) anyerror!u32 {
        
        return try XRSessionImpl.call_requestAnimationFrame(instance, callback);
    }

    pub fn call_updateTargetFrameRate(instance: *runtime.Instance, rate: f32) anyerror!*const anyopaque {
        
        return try XRSessionImpl.call_updateTargetFrameRate(instance, rate);
    }

    pub fn call_requestHitTestSource(instance: *runtime.Instance, options: XRHitTestOptionsInit) anyerror!*const anyopaque {
        
        return try XRSessionImpl.call_requestHitTestSource(instance, options);
    }

    pub fn call_updateRenderState(instance: *runtime.Instance, state: XRRenderStateInit) anyerror!void {
        
        return try XRSessionImpl.call_updateRenderState(instance, state);
    }

    pub fn call_restorePersistentAnchor(instance: *runtime.Instance, uuid: DOMString) anyerror!*const anyopaque {
        
        return try XRSessionImpl.call_restorePersistentAnchor(instance, uuid);
    }

    pub fn call_pauseDepthSensing(instance: *runtime.Instance) anyerror!void {
        return try XRSessionImpl.call_pauseDepthSensing(instance);
    }

    pub fn call_resumeDepthSensing(instance: *runtime.Instance) anyerror!void {
        return try XRSessionImpl.call_resumeDepthSensing(instance);
    }

};
