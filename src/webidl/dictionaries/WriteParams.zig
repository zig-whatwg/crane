//! WebIDL dictionary: WriteParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const WriteParams = struct {
    @"type": enums.WriteCommandType,
    size: ?u64 = null,
    position: ?u64 = null,
    data: ?*const anyopaque = null,
};
