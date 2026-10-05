//! WebIDL enum: AudioContextState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const AudioContextState = enum {
    _suspended_,
    _running_,
    _closed_,
    _interrupted_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "suspended", "running", "closed", "interrupted" };
};
