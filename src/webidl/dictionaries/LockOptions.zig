//! WebIDL dictionary: LockOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const LockOptions = struct {
    mode: ?*const anyopaque = null,
    ifAvailable: ?bool = null,
    steal: ?bool = null,
    signal: ?*const anyopaque = null,
};
