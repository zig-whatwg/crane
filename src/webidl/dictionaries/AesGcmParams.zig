//! WebIDL dictionary: AesGcmParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const AesGcmParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    iv: typedefs.BufferSource,
    additionalData: ?typedefs.BufferSource = null,
    tagLength: ?u8 = null,
};
