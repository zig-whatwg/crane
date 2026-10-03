//! WebIDL dictionary: KmacParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const KmacParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    length: u32,
    customization: ?typedefs.BufferSource = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"length"};
};
