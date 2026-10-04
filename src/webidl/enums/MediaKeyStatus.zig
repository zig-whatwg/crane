//! WebIDL enum: MediaKeyStatus
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const MediaKeyStatus = enum {
    _usable_,
    _expired_,
    _released_,
    _output_restricted_,
    _output_downscaled_,
    _usable_in_future_,
    _status_pending_,
    _internal_error_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "usable", "expired", "released", "output-restricted", "output-downscaled", "usable-in-future", "status-pending", "internal-error" };
};
