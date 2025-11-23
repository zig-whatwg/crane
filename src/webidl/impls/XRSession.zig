//! Implementation for XRSession interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XRSession = interfaces.XRSession;

pub const State = XRSession.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for visibilityState
pub fn get_visibilityState(instance: *runtime.Instance) ImplError!enums.XRVisibilityState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for frameRate
pub fn get_frameRate(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for supportedFrameRates
pub fn get_supportedFrameRates(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for renderState
pub fn get_renderState(instance: *runtime.Instance) ImplError!interfaces.XRRenderState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for inputSources
pub fn get_inputSources(instance: *runtime.Instance) ImplError!interfaces.XRInputSourceArray {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trackedSources
pub fn get_trackedSources(instance: *runtime.Instance) ImplError!interfaces.XRInputSourceArray {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for enabledFeatures
pub fn get_enabledFeatures(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isSystemKeyboardSupported
pub fn get_isSystemKeyboardSupported(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onend
pub fn get_onend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oninputsourceschange
pub fn get_oninputsourceschange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselect
pub fn get_onselect(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselectstart
pub fn get_onselectstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselectend
pub fn get_onselectend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsqueeze
pub fn get_onsqueeze(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsqueezestart
pub fn get_onsqueezestart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsqueezeend
pub fn get_onsqueezeend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onvisibilitychange
pub fn get_onvisibilitychange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onframeratechange
pub fn get_onframeratechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for domOverlayState
pub fn get_domOverlayState(instance: *runtime.Instance) ImplError!dictionaries.XRDOMOverlayState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for depthUsage
pub fn get_depthUsage(instance: *runtime.Instance) ImplError!enums.XRDepthUsage {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for depthDataFormat
pub fn get_depthDataFormat(instance: *runtime.Instance) ImplError!enums.XRDepthDataFormat {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for depthType
pub fn get_depthType(instance: *runtime.Instance) ImplError!enums.XRDepthType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for depthActive
pub fn get_depthActive(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for persistentAnchors
pub fn get_persistentAnchors(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for preferredReflectionFormat
pub fn get_preferredReflectionFormat(instance: *runtime.Instance) ImplError!enums.XRReflectionFormat {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for environmentBlendMode
pub fn get_environmentBlendMode(instance: *runtime.Instance) ImplError!enums.XREnvironmentBlendMode {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for interactionMode
pub fn get_interactionMode(instance: *runtime.Instance) ImplError!enums.XRInteractionMode {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onend
pub fn set_onend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oninputsourceschange
pub fn set_oninputsourceschange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselect
pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselectstart
pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselectend
pub fn set_onselectend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsqueeze
pub fn set_onsqueeze(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsqueezestart
pub fn set_onsqueezestart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsqueezeend
pub fn set_onsqueezeend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onvisibilitychange
pub fn set_onvisibilitychange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onframeratechange
pub fn set_onframeratechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: deletePersistentAnchor
pub fn call_deletePersistentAnchor(instance: *runtime.Instance, uuid: runtime.DOMString) ImplError!*const anyopaque {
    _ = instance;
    _ = uuid;
    return error.NotImplemented;
}

/// Operation: requestHitTestSourceForTransientInput
pub fn call_requestHitTestSourceForTransientInput(instance: *runtime.Instance, options: dictionaries.XRTransientInputHitTestOptionsInit) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: requestReferenceSpace
pub fn call_requestReferenceSpace(instance: *runtime.Instance, @"type": enums.XRReferenceSpaceType) ImplError!*const anyopaque {
    _ = instance;
    _ = @"type";
    return error.NotImplemented;
}

/// Operation: cancelAnimationFrame
pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) ImplError!void {
    _ = instance;
    _ = handle;
    return error.NotImplemented;
}

/// Operation: requestLightProbe
pub fn call_requestLightProbe(instance: *runtime.Instance, options: dictionaries.XRLightProbeInit) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: end
pub fn call_end(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: initiateRoomCapture
pub fn call_initiateRoomCapture(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestAnimationFrame
pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: callbacks.XRFrameRequestCallback) ImplError!u32 {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

/// Operation: updateTargetFrameRate
pub fn call_updateTargetFrameRate(instance: *runtime.Instance, rate: f32) ImplError!*const anyopaque {
    _ = instance;
    _ = rate;
    return error.NotImplemented;
}

/// Operation: requestHitTestSource
pub fn call_requestHitTestSource(instance: *runtime.Instance, options: dictionaries.XRHitTestOptionsInit) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: updateRenderState
pub fn call_updateRenderState(instance: *runtime.Instance, state: dictionaries.XRRenderStateInit) ImplError!void {
    _ = instance;
    _ = state;
    return error.NotImplemented;
}

/// Operation: restorePersistentAnchor
pub fn call_restorePersistentAnchor(instance: *runtime.Instance, uuid: runtime.DOMString) ImplError!*const anyopaque {
    _ = instance;
    _ = uuid;
    return error.NotImplemented;
}

/// Operation: pauseDepthSensing
pub fn call_pauseDepthSensing(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: resumeDepthSensing
pub fn call_resumeDepthSensing(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

