//! WebIDL enum: PressureState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const PressureState = enum {
    _nominal_,
    _fair_,
    _serious_,
    _critical_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "nominal", "fair", "serious", "critical" };
};
