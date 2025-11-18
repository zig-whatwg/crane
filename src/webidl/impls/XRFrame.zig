//! Implementation for XRFrame interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const XRFrame = @import("interfaces").XRFrame;

pub const State = XRFrame.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for session
pub fn get_session(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for predictedDisplayTime
pub fn get_predictedDisplayTime(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for body
pub fn get_body(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for trackedAnchors
pub fn get_trackedAnchors(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for detectedPlanes
pub fn get_detectedPlanes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for detectedMeshes
pub fn get_detectedMeshes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for metaData
pub fn get_metaData(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: getViewerPose
pub fn call_getViewerPose(instance: *runtime.Instance, referenceSpace: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = referenceSpace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPose
pub fn call_getPose(instance: *runtime.Instance, space: anyopaque, baseSpace: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = space;
    _ = baseSpace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getHitTestResults
pub fn call_getHitTestResults(instance: *runtime.Instance, hitTestSource: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = hitTestSource;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getHitTestResultsForTransientInput
pub fn call_getHitTestResultsForTransientInput(instance: *runtime.Instance, hitTestSource: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = hitTestSource;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getDepthInformation
pub fn call_getDepthInformation(instance: *runtime.Instance, view: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = view;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createAnchor
pub fn call_createAnchor(instance: *runtime.Instance, pose: anyopaque, space: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = pose;
    _ = space;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getLightEstimate
pub fn call_getLightEstimate(instance: *runtime.Instance, lightProbe: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = lightProbe;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getJointPose
pub fn call_getJointPose(instance: *runtime.Instance, joint: anyopaque, baseSpace: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = joint;
    _ = baseSpace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fillJointRadii
pub fn call_fillJointRadii(instance: *runtime.Instance, jointSpaces: anyopaque, radii: anyopaque) ImplError!bool {
    _ = instance;
    _ = jointSpaces;
    _ = radii;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fillPoses
pub fn call_fillPoses(instance: *runtime.Instance, spaces: anyopaque, baseSpace: anyopaque, transforms: anyopaque) ImplError!bool {
    _ = instance;
    _ = spaces;
    _ = baseSpace;
    _ = transforms;
    // TODO: Implement operation
    return error.NotImplemented;
}

