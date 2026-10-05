//! WebIDL enum: SmartCardDisposition
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const SmartCardDisposition = enum {
    _leave_,
    _reset_,
    _unpower_,
    _eject_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "leave", "reset", "unpower", "eject" };
};
