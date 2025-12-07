//! WebIDL dictionary: ProfilerStack
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const ProfilerStack = struct {
    parentId: ?u64 = null,
    frameId: u64,
};
