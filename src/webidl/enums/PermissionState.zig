//! WebIDL enum: PermissionState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const PermissionState = enum {
    _granted_,
    _denied_,
    _prompt_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "granted", "denied", "prompt" };
};
