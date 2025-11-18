//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRSessionImpl = @import("../impls/XRSession.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        XRSessionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRSessionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_visibilityState(state);
    }

    pub fn get_frameRate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_frameRate(state);
    }

    pub fn get_supportedFrameRates(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_supportedFrameRates(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_renderState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_renderState) |cached| {
            return cached;
        }
        const value = XRSessionImpl.get_renderState(state);
        state.cached_renderState = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSources(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_inputSources) |cached| {
            return cached;
        }
        const value = XRSessionImpl.get_inputSources(state);
        state.cached_inputSources = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_trackedSources(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_trackedSources) |cached| {
            return cached;
        }
        const value = XRSessionImpl.get_trackedSources(state);
        state.cached_trackedSources = value;
        return value;
    }

    pub fn get_enabledFeatures(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_enabledFeatures(state);
    }

    pub fn get_isSystemKeyboardSupported(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRSessionImpl.get_isSystemKeyboardSupported(state);
    }

    pub fn get_onend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onend(state);
    }

    pub fn set_onend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onend(state, value);
    }

    pub fn get_oninputsourceschange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_oninputsourceschange(state);
    }

    pub fn set_oninputsourceschange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_oninputsourceschange(state, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onselect(state);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onselect(state, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onselectstart(state);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onselectstart(state, value);
    }

    pub fn get_onselectend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onselectend(state);
    }

    pub fn set_onselectend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onselectend(state, value);
    }

    pub fn get_onsqueeze(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onsqueeze(state);
    }

    pub fn set_onsqueeze(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onsqueeze(state, value);
    }

    pub fn get_onsqueezestart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onsqueezestart(state);
    }

    pub fn set_onsqueezestart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onsqueezestart(state, value);
    }

    pub fn get_onsqueezeend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onsqueezeend(state);
    }

    pub fn set_onsqueezeend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onsqueezeend(state, value);
    }

    pub fn get_onvisibilitychange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onvisibilitychange(state);
    }

    pub fn set_onvisibilitychange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onvisibilitychange(state, value);
    }

    pub fn get_onframeratechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_onframeratechange(state);
    }

    pub fn set_onframeratechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSessionImpl.set_onframeratechange(state, value);
    }

    pub fn get_domOverlayState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_domOverlayState(state);
    }

    pub fn get_depthUsage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_depthUsage(state);
    }

    pub fn get_depthDataFormat(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_depthDataFormat(state);
    }

    pub fn get_depthType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_depthType(state);
    }

    pub fn get_depthActive(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_depthActive(state);
    }

    pub fn get_persistentAnchors(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_persistentAnchors(state);
    }

    pub fn get_preferredReflectionFormat(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_preferredReflectionFormat(state);
    }

    pub fn get_environmentBlendMode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_environmentBlendMode(state);
    }

    pub fn get_interactionMode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.get_interactionMode(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_when(state, type_, options);
    }

    pub fn call_deletePersistentAnchor(instance: *runtime.Instance, uuid: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_deletePersistentAnchor(state, uuid);
    }

    pub fn call_requestHitTestSourceForTransientInput(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_requestHitTestSourceForTransientInput(state, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestReferenceSpace(instance: *runtime.Instance, type_: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XRSessionImpl.call_requestReferenceSpace(state, type_);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_cancelAnimationFrame(state, handle);
    }

    pub fn call_requestLightProbe(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_requestLightProbe(state, options);
    }

    pub fn call_end(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.call_end(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_initiateRoomCapture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.call_initiateRoomCapture(state);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: anyopaque) u32 {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_requestAnimationFrame(state, callback);
    }

    pub fn call_updateTargetFrameRate(instance: *runtime.Instance, rate: f32) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_updateTargetFrameRate(state, rate);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_dispatchEvent(state, event);
    }

    pub fn call_requestHitTestSource(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_requestHitTestSource(state, options);
    }

    pub fn call_updateRenderState(instance: *runtime.Instance, state: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_updateRenderState(state, state);
    }

    pub fn call_restorePersistentAnchor(instance: *runtime.Instance, uuid: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XRSessionImpl.call_restorePersistentAnchor(state, uuid);
    }

    pub fn call_pauseDepthSensing(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.call_pauseDepthSensing(state);
    }

    pub fn call_resumeDepthSensing(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSessionImpl.call_resumeDepthSensing(state);
    }

};
