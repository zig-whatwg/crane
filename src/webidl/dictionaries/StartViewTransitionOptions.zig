//! WebIDL dictionary: StartViewTransitionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const typedefs = @import("typedefs");

pub const StartViewTransitionOptions = struct {
    update: ?callbacks.ViewTransitionUpdateCallback = null,
    types: ?[]const runtime.DOMString = null,
};
