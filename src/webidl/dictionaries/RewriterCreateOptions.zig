//! WebIDL dictionary: RewriterCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const typedefs = @import("typedefs");
const RewriterCreateCoreOptions = @import("RewriterCreateCoreOptions.zig").RewriterCreateCoreOptions;

pub const RewriterCreateOptions = struct {
    // Inherited from RewriterCreateCoreOptions
    base: RewriterCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
    sharedContext: ?runtime.DOMString = null,
};
