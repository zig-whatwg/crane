//! WebIDL enum: MLConv2dFilterOperandLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const MLConv2dFilterOperandLayout = enum {
    _oihw_,
    _hwio_,
    _ohwi_,
    _ihwo_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "oihw", "hwio", "ohwi", "ihwo" };
};
