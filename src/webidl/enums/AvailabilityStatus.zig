//! WebIDL enum: AvailabilityStatus
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const AvailabilityStatus = enum {
    _unavailable_,
    _downloadable_,
    _downloading_,
    _available_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "unavailable", "downloadable", "downloading", "available" };
};
