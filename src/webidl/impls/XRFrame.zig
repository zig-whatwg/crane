//! Implementation for XRFrame interface
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
const XRFrame = interfaces.XRFrame;

pub const State = XRFrame.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Getter for session
pub fn get_session(instance: *runtime.Instance) ImplError!interfaces.XRSession {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for predictedDisplayTime
pub fn get_predictedDisplayTime(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for body
pub fn get_body(instance: *runtime.Instance) ImplError!interfaces.XRBody {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trackedAnchors
pub fn get_trackedAnchors(instance: *runtime.Instance) ImplError!interfaces.XRAnchorSet {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for detectedPlanes
pub fn get_detectedPlanes(instance: *runtime.Instance) ImplError!interfaces.XRPlaneSet {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for detectedMeshes
pub fn get_detectedMeshes(instance: *runtime.Instance) ImplError!interfaces.XRMeshSet {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for metaData
pub fn get_metaData(instance: *runtime.Instance) ImplError!dictionaries.XRMetadata {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createAnchor
pub fn call_createAnchor(instance: *runtime.Instance, pose: interfaces.XRRigidTransform, space: interfaces.XRSpace) ImplError!*const anyopaque {
    _ = instance;
    _ = pose;
    _ = space;
    return error.NotImplemented;
}

/// Operation: getViewerPose
pub fn call_getViewerPose(instance: *runtime.Instance, referenceSpace: interfaces.XRReferenceSpace) ImplError!interfaces.XRViewerPose {
    _ = instance;
    _ = referenceSpace;
    return error.NotImplemented;
}

/// Operation: getHitTestResults
pub fn call_getHitTestResults(instance: *runtime.Instance, hitTestSource: interfaces.XRHitTestSource) ImplError!*const anyopaque {
    _ = instance;
    _ = hitTestSource;
    return error.NotImplemented;
}

/// Operation: getLightEstimate
pub fn call_getLightEstimate(instance: *runtime.Instance, lightProbe: interfaces.XRLightProbe) ImplError!interfaces.XRLightEstimate {
    _ = instance;
    _ = lightProbe;
    return error.NotImplemented;
}

/// Operation: getPose
pub fn call_getPose(instance: *runtime.Instance, space: interfaces.XRSpace, baseSpace: interfaces.XRSpace) ImplError!interfaces.XRPose {
    _ = instance;
    _ = space;
    _ = baseSpace;
    return error.NotImplemented;
}

/// Operation: getHitTestResultsForTransientInput
pub fn call_getHitTestResultsForTransientInput(instance: *runtime.Instance, hitTestSource: interfaces.XRTransientInputHitTestSource) ImplError!*const anyopaque {
    _ = instance;
    _ = hitTestSource;
    return error.NotImplemented;
}

/// Operation: fillPoses
pub fn call_fillPoses(instance: *runtime.Instance, spaces: *const anyopaque, baseSpace: interfaces.XRSpace, transforms: *const anyopaque) ImplError!bool {
    _ = instance;
    _ = spaces;
    _ = baseSpace;
    _ = transforms;
    return error.NotImplemented;
}

/// Operation: getJointPose
pub fn call_getJointPose(instance: *runtime.Instance, joint: interfaces.XRJointSpace, baseSpace: interfaces.XRSpace) ImplError!interfaces.XRJointPose {
    _ = instance;
    _ = joint;
    _ = baseSpace;
    return error.NotImplemented;
}

/// Operation: fillJointRadii
pub fn call_fillJointRadii(instance: *runtime.Instance, jointSpaces: *const anyopaque, radii: *const anyopaque) ImplError!bool {
    _ = instance;
    _ = jointSpaces;
    _ = radii;
    return error.NotImplemented;
}

/// Operation: getDepthInformation
pub fn call_getDepthInformation(instance: *runtime.Instance, view: interfaces.XRView) ImplError!interfaces.XRCPUDepthInformation {
    _ = instance;
    _ = view;
    return error.NotImplemented;
}

