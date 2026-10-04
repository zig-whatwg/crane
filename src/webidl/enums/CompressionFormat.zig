//! WebIDL enum: CompressionFormat
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const CompressionFormat = enum {
    _deflate_,
    _deflate_raw_,
    _gzip_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "deflate", "deflate-raw", "gzip" };
};
