//! WebIDL enum: KAnonStatus
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const KAnonStatus = enum {
    _passedAndEnforced_,
    _passedNotEnforced_,
    _belowThreshold_,
    _notCalculated_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "passedAndEnforced", "passedNotEnforced", "belowThreshold", "notCalculated" };
};
