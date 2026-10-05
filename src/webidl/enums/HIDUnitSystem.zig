//! WebIDL enum: HIDUnitSystem
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const HIDUnitSystem = enum {
    _none_,
    _si_linear_,
    _si_rotation_,
    _english_linear_,
    _english_rotation_,
    _vendor_defined_,
    _reserved_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "none", "si-linear", "si-rotation", "english-linear", "english-rotation", "vendor-defined", "reserved" };
};
