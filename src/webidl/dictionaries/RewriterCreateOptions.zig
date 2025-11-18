//! WebIDL dictionary: RewriterCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RewriterCreateCoreOptions = @import("RewriterCreateCoreOptions.zig").RewriterCreateCoreOptions;

pub const RewriterCreateOptions = struct {
    // Inherited from RewriterCreateCoreOptions
    base: RewriterCreateCoreOptions,

    signal: ?anyopaque = null,
    monitor: ?anyopaque = null,
    sharedContext: ?runtime.DOMString = null,
};
