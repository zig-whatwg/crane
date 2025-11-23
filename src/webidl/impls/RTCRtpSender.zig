//! Implementation for RTCRtpSender interface
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
const RTCRtpSender = interfaces.RTCRtpSender;

pub const State = RTCRtpSender.State;

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

/// Getter for track
pub fn get_track(instance: *runtime.Instance) ImplError!interfaces.MediaStreamTrack {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for transport
pub fn get_transport(instance: *runtime.Instance) ImplError!interfaces.RTCDtlsTransport {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for dtmf
pub fn get_dtmf(instance: *runtime.Instance) ImplError!interfaces.RTCDTMFSender {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for transform
pub fn get_transform(instance: *runtime.Instance) ImplError!typedefs.RTCRtpTransform {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for transform
pub fn set_transform(instance: *runtime.Instance, value: typedefs.RTCRtpTransform) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: replaceTrack
pub fn call_replaceTrack(instance: *runtime.Instance, withTrack: interfaces.MediaStreamTrack) ImplError!*const anyopaque {
    _ = instance;
    _ = withTrack;
    return error.NotImplemented;
}

/// Operation: getCapabilities
pub fn call_getCapabilities(instance: *runtime.Instance, kind: runtime.DOMString) ImplError!dictionaries.RTCRtpCapabilities {
    _ = instance;
    _ = kind;
    return error.NotImplemented;
}

/// Operation: getStats
pub fn call_getStats(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getParameters
pub fn call_getParameters(instance: *runtime.Instance) ImplError!dictionaries.RTCRtpSendParameters {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setStreams
pub fn call_setStreams(instance: *runtime.Instance, streams: interfaces.MediaStream) ImplError!void {
    _ = instance;
    _ = streams;
    return error.NotImplemented;
}

/// Operation: setParameters
pub fn call_setParameters(instance: *runtime.Instance, parameters: dictionaries.RTCRtpSendParameters, setParameterOptions: dictionaries.RTCSetParameterOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = parameters;
    _ = setParameterOptions;
    return error.NotImplemented;
}

