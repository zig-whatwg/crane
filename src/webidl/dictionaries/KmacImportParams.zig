//! WebIDL dictionary: KmacImportParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const KmacImportParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    length: ?u32 = null,
};
