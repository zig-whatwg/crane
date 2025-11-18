//! WebIDL dictionary: WriterCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const WriterCreateCoreOptions = @import("WriterCreateCoreOptions.zig").WriterCreateCoreOptions;

pub const WriterCreateOptions = struct {
    // Inherited from WriterCreateCoreOptions
    base: WriterCreateCoreOptions,

    signal: ?anyopaque = null,
    monitor: ?anyopaque = null,
    sharedContext: ?runtime.DOMString = null,
};
