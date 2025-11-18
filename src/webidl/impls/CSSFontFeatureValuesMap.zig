//! Implementation for CSSFontFeatureValuesMap interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CSSFontFeatureValuesMap = @import("interfaces").CSSFontFeatureValuesMap;

pub const State = CSSFontFeatureValuesMap.State;

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

/// Operation: set
pub fn call_set(instance: *runtime.Instance, featureValueName: anyopaque, values: anyopaque) ImplError!void {
    _ = instance;
    _ = featureValueName;
    _ = values;
    // TODO: Implement operation
    return error.NotImplemented;
}

