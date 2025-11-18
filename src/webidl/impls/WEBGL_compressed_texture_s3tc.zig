//! Implementation for WEBGL_compressed_texture_s3tc interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_s3tc = @import("interfaces").WEBGL_compressed_texture_s3tc;

pub const State = WEBGL_compressed_texture_s3tc.State;

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

