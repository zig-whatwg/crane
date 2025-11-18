//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRSessionImpl = @import("impls").XRSession;
const EventTarget = @import("interfaces").EventTarget;
const Promise<XRTransientInputHitTestSource> = @import("interfaces").Promise<XRTransientInputHitTestSource>;
const XRDepthDataFormat = @import("enums").XRDepthDataFormat;
const XRDOMOverlayState = @import("dictionaries").XRDOMOverlayState;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const XRFrameRequestCallback = @import("callbacks").XRFrameRequestCallback;
const Promise<XRAnchor> = @import("interfaces").Promise<XRAnchor>;
const XRRenderStateInit = @import("dictionaries").XRRenderStateInit;
const float = @import("interfaces").float;
const XRDepthUsage = @import("enums").XRDepthUsage;
const Promise<XRLightProbe> = @import("interfaces").Promise<XRLightProbe>;
const XREnvironmentBlendMode = @import("enums").XREnvironmentBlendMode;
const XRVisibilityState = @import("enums").XRVisibilityState;
const XRInputSourceArray = @import("interfaces").XRInputSourceArray;
const XRHitTestOptionsInit = @import("dictionaries").XRHitTestOptionsInit;
const EventHandler = @import("typedefs").EventHandler;
const XRReferenceSpaceType = @import("enums").XRReferenceSpaceType;
const Float32Array = @import("interfaces").Float32Array;
const XRTransientInputHitTestOptionsInit = @import("dictionaries").XRTransientInputHitTestOptionsInit;
const XRLightProbeInit = @import("dictionaries").XRLightProbeInit;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const XRDepthType = @import("enums").XRDepthType;
const XRRenderState = @import("interfaces").XRRenderState;
const XRReflectionFormat = @import("enums").XRReflectionFormat;
const Promise<XRHitTestSource> = @import("interfaces").Promise<XRHitTestSource>;
const boolean = @import("interfaces").boolean;
const XRInteractionMode = @import("enums").XRInteractionMode;
const Promise<XRReferenceSpace> = @import("interfaces").Promise<XRReferenceSpace>;

pub const XRSession = struct {
    pub const Meta = struct {
        pub const name = "XRSession";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            visibilityState: XRVisibilityState = undefined,
            frameRate: ?f32 = null,
            supportedFrameRates: ?Float32Array = null,
            renderState: XRRenderState = undefined,
            inputSources: XRInputSourceArray = undefined,
            trackedSources: XRInputSourceArray = undefined,
            enabledFeatures: FrozenArray<DOMString> = undefined,
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
            persistentAnchors: FrozenArray<DOMString> = undefined,
            preferredReflectionFormat: XRReflectionFormat = undefined,
            environmentBlendMode: XREnvironmentBlendMode = undefined,
            interactionMode: XRInteractionMode = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRSession, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_cancelAnimationFrame = &call_cancelAnimationFrame,
        .call_deletePersistentAnchor = &call_deletePersistentAnchor,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_end = &call_end,
        .call_initiateRoomCapture = &call_initiateRoomCapture,
        .call_pauseDepthSensing = &call_pauseDepthSensing,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestAnimationFrame = &call_requestAnimationFrame,
        .call_requestHitTestSource = &call_requestHitTestSource,
        .call_requestHitTestSourceForTransientInput = &call_requestHitTestSourceForTransientInput,
        .call_requestLightProbe = &call_requestLightProbe,
        .call_requestReferenceSpace = &call_requestReferenceSpace,
        .call_restorePersistentAnchor = &call_restorePersistentAnchor,
        .call_resumeDepthSensing = &call_resumeDepthSensing,
        .call_updateRenderState = &call_updateRenderState,
        .call_updateTargetFrameRate = &call_updateTargetFrameRate,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XRSessionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRSessionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyerror!XRVisibilityState {
        return try XRSessionImpl.get_visibilityState(instance);
    }

    pub fn get_frameRate(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRSessionImpl.get_frameRate(instance);
    }

    pub fn get_supportedFrameRates(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRSessionImpl.get_supportedFrameRates(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_renderState(instance: *runtime.Instance) anyerror!XRRenderState {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_renderState) |cached| {
            return cached;
        }
        const value = try XRSessionImpl.get_renderState(instance);
        state.cached_renderState = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSources(instance: *runtime.Instance) anyerror!XRInputSourceArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_inputSources) |cached| {
            return cached;
        }
        const value = try XRSessionImpl.get_inputSources(instance);
        state.cached_inputSources = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_trackedSources(instance: *runtime.Instance) anyerror!XRInputSourceArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_trackedSources) |cached| {
            return cached;
        }
        const value = try XRSessionImpl.get_trackedSources(instance);
        state.cached_trackedSources = value;
        return value;
    }

    pub fn get_enabledFeatures(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn get_domOverlayState(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRSessionImpl.get_domOverlayState(instance);
    }

    pub fn get_depthUsage(instance: *runtime.Instance) anyerror!XRDepthUsage {
        return try XRSessionImpl.get_depthUsage(instance);
    }

    pub fn get_depthDataFormat(instance: *runtime.Instance) anyerror!XRDepthDataFormat {
        return try XRSessionImpl.get_depthDataFormat(instance);
    }

    pub fn get_depthType(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRSessionImpl.get_depthType(instance);
    }

    pub fn get_depthActive(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRSessionImpl.get_depthActive(instance);
    }

    pub fn get_persistentAnchors(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRSessionImpl.call_when(instance, type_, options);
    }

    pub fn call_deletePersistentAnchor(instance: *runtime.Instance, uuid: DOMString) anyerror!anyopaque {
        
        return try XRSessionImpl.call_deletePersistentAnchor(instance, uuid);
    }

    pub fn call_requestHitTestSourceForTransientInput(instance: *runtime.Instance, options: XRTransientInputHitTestOptionsInit) anyerror!anyopaque {
        
        return try XRSessionImpl.call_requestHitTestSourceForTransientInput(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestReferenceSpace(instance: *runtime.Instance, type_: XRReferenceSpaceType) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try XRSessionImpl.call_requestReferenceSpace(instance, type_);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
        
        return try XRSessionImpl.call_cancelAnimationFrame(instance, handle);
    }

    pub fn call_requestLightProbe(instance: *runtime.Instance, options: XRLightProbeInit) anyerror!anyopaque {
        
        return try XRSessionImpl.call_requestLightProbe(instance, options);
    }

    pub fn call_end(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRSessionImpl.call_end(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRSessionImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRSessionImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_initiateRoomCapture(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRSessionImpl.call_initiateRoomCapture(instance);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: XRFrameRequestCallback) anyerror!u32 {
        
        return try XRSessionImpl.call_requestAnimationFrame(instance, callback);
    }

    pub fn call_updateTargetFrameRate(instance: *runtime.Instance, rate: f32) anyerror!anyopaque {
        
        return try XRSessionImpl.call_updateTargetFrameRate(instance, rate);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRSessionImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_requestHitTestSource(instance: *runtime.Instance, options: XRHitTestOptionsInit) anyerror!anyopaque {
        
        return try XRSessionImpl.call_requestHitTestSource(instance, options);
    }

    pub fn call_updateRenderState(instance: *runtime.Instance, state: XRRenderStateInit) anyerror!void {
        
        return try XRSessionImpl.call_updateRenderState(instance, state);
    }

    pub fn call_restorePersistentAnchor(instance: *runtime.Instance, uuid: DOMString) anyerror!anyopaque {
        
        return try XRSessionImpl.call_restorePersistentAnchor(instance, uuid);
    }

    pub fn call_pauseDepthSensing(instance: *runtime.Instance) anyerror!void {
        return try XRSessionImpl.call_pauseDepthSensing(instance);
    }

    pub fn call_resumeDepthSensing(instance: *runtime.Instance) anyerror!void {
        return try XRSessionImpl.call_resumeDepthSensing(instance);
    }

};
