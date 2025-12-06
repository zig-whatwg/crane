//! WebIDL dictionary: WriteParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WriteParams = struct {
    type: *const anyopaque,
    size: ?u64 = null,
    position: ?u64 = null,
    data: ?*const anyopaque = null,
};
