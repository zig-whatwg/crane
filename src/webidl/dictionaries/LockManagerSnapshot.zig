//! WebIDL dictionary: LockManagerSnapshot
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const LockInfo = @import("LockInfo.zig").LockInfo;

pub const LockManagerSnapshot = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    held: ?[]const LockInfo = null,
    pending: ?[]const LockInfo = null,
};
