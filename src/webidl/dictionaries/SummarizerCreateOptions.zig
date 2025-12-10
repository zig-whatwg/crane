//! WebIDL dictionary: SummarizerCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const typedefs = @import("typedefs");
const SummarizerCreateCoreOptions = @import("SummarizerCreateCoreOptions.zig").SummarizerCreateCoreOptions;

pub const SummarizerCreateOptions = struct {
    // Inherited from SummarizerCreateCoreOptions
    base: SummarizerCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
    sharedContext: ?runtime.DOMString = null,
};
