//! WebIDL dictionary: AeadParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const AeadParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    iv: anyopaque,
    additionalData: ?anyopaque = null,
    tagLength: ?u8 = null,
};
