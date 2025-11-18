//! WebIDL dictionary: HmacImportParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const HmacImportParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    hash: anyopaque,
    length: ?u32 = null,
};
