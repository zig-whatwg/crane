//! WebIDL enum: SmartCardConnectionState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const SmartCardConnectionState = enum {
    _absent_,
    _present_,
    _swallowed_,
    _powered_,
    _negotiable_,
    _t0_,
    _t1_,
    _raw_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "absent", "present", "swallowed", "powered", "negotiable", "t0", "t1", "raw" };
};
