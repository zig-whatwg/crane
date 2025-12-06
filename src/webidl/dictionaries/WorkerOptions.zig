//! WebIDL dictionary: WorkerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WorkerOptions = struct {
    name: ?runtime.DOMString = null,
    type: ?*const anyopaque = null,
    credentials: ?*const anyopaque = null,
};
