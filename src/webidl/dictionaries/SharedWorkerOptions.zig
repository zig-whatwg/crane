//! WebIDL dictionary: SharedWorkerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const WorkerOptions = @import("WorkerOptions.zig").WorkerOptions;

pub const SharedWorkerOptions = struct {
    // Inherited from WorkerOptions
    base: WorkerOptions,

    sameSiteCookies: ?enums.SameSiteCookiesType = null,
};
