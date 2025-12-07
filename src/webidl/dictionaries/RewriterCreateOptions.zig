//! WebIDL dictionary: RewriterCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const callbacks = @import("callbacks");
const RewriterCreateCoreOptions = @import("RewriterCreateCoreOptions.zig").RewriterCreateCoreOptions;

pub const RewriterCreateOptions = struct {
    // Inherited from RewriterCreateCoreOptions
    base: RewriterCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
    sharedContext: ?runtime.DOMString = null,
};
