//! WebIDL enum: RTCDegradationPreference
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCDegradationPreference = enum {
    _maintain_framerate_,
    _maintain_resolution_,
    _balanced_,
    _maintain_framerate_and_resolution_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "maintain-framerate", "maintain-resolution", "balanced", "maintain-framerate-and-resolution" };
};
