//! WebIDL dictionary: WriterCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const callbacks = @import("callbacks");
const WriterCreateCoreOptions = @import("WriterCreateCoreOptions.zig").WriterCreateCoreOptions;

pub const WriterCreateOptions = struct {
    // Inherited from WriterCreateCoreOptions
    base: WriterCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
    sharedContext: ?runtime.DOMString = null,
};
