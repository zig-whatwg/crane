//! WebIDL enum: MediaKeySessionClosedReason
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const MediaKeySessionClosedReason = enum {
    _internal_error_,
    _closed_by_application_,
    _release_acknowledged_,
    _hardware_context_reset_,
    _resource_evicted_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "internal-error", "closed-by-application", "release-acknowledged", "hardware-context-reset", "resource-evicted" };
};
