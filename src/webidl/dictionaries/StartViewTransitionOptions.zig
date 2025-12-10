//! WebIDL dictionary: StartViewTransitionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const callbacks = @import("callbacks");

pub const StartViewTransitionOptions = struct {
    update: ?callbacks.ViewTransitionUpdateCallback = null,
    types: ?[]const runtime.DOMString = null,
};
