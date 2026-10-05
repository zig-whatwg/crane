//! WebIDL enum: RTCStatsIceCandidatePairState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCStatsIceCandidatePairState = enum {
    _frozen_,
    _waiting_,
    _in_progress_,
    _failed_,
    _succeeded_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "frozen", "waiting", "in-progress", "failed", "succeeded" };
};
