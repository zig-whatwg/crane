//! WebIDL enum: RequestMode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RequestMode = enum {
    _navigate_,
    _same_origin_,
    _no_cors_,
    _cors_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "navigate", "same-origin", "no-cors", "cors" };
};
