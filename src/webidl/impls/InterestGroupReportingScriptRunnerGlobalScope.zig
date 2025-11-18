//! Implementation for InterestGroupReportingScriptRunnerGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupReportingScriptRunnerGlobalScope = @import("interfaces").InterestGroupReportingScriptRunnerGlobalScope;

pub const State = InterestGroupReportingScriptRunnerGlobalScope.State;

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

/// Getter for privateAggregation
pub fn get_privateAggregation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for protectedAudience
pub fn get_protectedAudience(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: sendReportTo
pub fn call_sendReportTo(instance: *runtime.Instance, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: registerAdBeacon
pub fn call_registerAdBeacon(instance: *runtime.Instance, map: anyopaque) ImplError!void {
    _ = instance;
    _ = map;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: registerAdMacro
pub fn call_registerAdMacro(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = name;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

