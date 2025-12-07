//! WebIDL dictionary: LockManagerSnapshot
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const LockInfo = @import("LockInfo.zig").LockInfo;

pub const LockManagerSnapshot = struct {
    held: ?[]const LockInfo = null,
    pending: ?[]const LockInfo = null,
};
