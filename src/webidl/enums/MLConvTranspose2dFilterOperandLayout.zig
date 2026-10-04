//! WebIDL enum: MLConvTranspose2dFilterOperandLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const MLConvTranspose2dFilterOperandLayout = enum {
    _iohw_,
    _hwoi_,
    _ohwi_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "iohw", "hwoi", "ohwi" };
};
