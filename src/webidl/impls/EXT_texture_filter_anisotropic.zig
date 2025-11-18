//! Implementation for EXT_texture_filter_anisotropic interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_filter_anisotropic = @import("interfaces").EXT_texture_filter_anisotropic;

pub const State = EXT_texture_filter_anisotropic.State;

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

