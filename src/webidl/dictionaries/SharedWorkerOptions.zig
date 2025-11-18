//! WebIDL dictionary: SharedWorkerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const WorkerOptions = @import("WorkerOptions.zig").WorkerOptions;

pub const SharedWorkerOptions = struct {
    // Inherited from WorkerOptions
    base: WorkerOptions,

    sameSiteCookies: ?anyopaque = null,
};
