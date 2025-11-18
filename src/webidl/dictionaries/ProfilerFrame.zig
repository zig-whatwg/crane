//! WebIDL dictionary: ProfilerFrame
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ProfilerFrame = struct {
    name: runtime.DOMString,
    resourceId: ?u64 = null,
    line: ?u64 = null,
    column: ?u64 = null,
};
