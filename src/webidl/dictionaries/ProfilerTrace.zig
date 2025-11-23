//! WebIDL dictionary: ProfilerTrace
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ProfilerTrace = struct {
    resources: *const anyopaque,
    frames: *const anyopaque,
    stacks: *const anyopaque,
    samples: *const anyopaque,
};
