//! Implementation for DelegatedInkTrailPresenter interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const DelegatedInkTrailPresenter = @import("interfaces").DelegatedInkTrailPresenter;

pub const State = DelegatedInkTrailPresenter.State;

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

/// Getter for presentationArea
pub fn get_presentationArea(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: updateInkTrailStartPoint
pub fn call_updateInkTrailStartPoint(instance: *runtime.Instance, event: anyopaque, style: anyopaque) ImplError!void {
    _ = instance;
    _ = event;
    _ = style;
    // TODO: Implement operation
    return error.NotImplemented;
}

