//! WebIDL enum: ResponseType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ResponseType = enum {
    _basic_,
    _cors_,
    _default_,
    _error_,
    _opaque_,
    _opaqueredirect_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "basic", "cors", "default", "error", "opaque", "opaqueredirect" };
};
