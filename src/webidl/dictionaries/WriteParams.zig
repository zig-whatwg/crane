//! WebIDL dictionary: WriteParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WriteParams = struct {
    @"type": anyopaque,
    size: ?u64 = null,
    position: ?u64 = null,
    data: ?anyopaque = null,
};
