//! WebIDL dictionary: SummarizerCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const SummarizerCreateCoreOptions = @import("SummarizerCreateCoreOptions.zig").SummarizerCreateCoreOptions;

pub const SummarizerCreateOptions = struct {
    // Inherited from SummarizerCreateCoreOptions
    base: SummarizerCreateCoreOptions,

    signal: ?anyopaque = null,
    monitor: ?anyopaque = null,
    sharedContext: ?runtime.DOMString = null,
};
