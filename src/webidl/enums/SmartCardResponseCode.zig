//! WebIDL enum: SmartCardResponseCode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const SmartCardResponseCode = enum {
    _no_service_,
    _no_smartcard_,
    _not_ready_,
    _not_transacted_,
    _proto_mismatch_,
    _reader_unavailable_,
    _removed_card_,
    _reset_card_,
    _server_too_busy_,
    _sharing_violation_,
    _system_cancelled_,
    _unknown_reader_,
    _unpowered_card_,
    _unresponsive_card_,
    _unsupported_card_,
    _unsupported_feature_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "no-service", "no-smartcard", "not-ready", "not-transacted", "proto-mismatch", "reader-unavailable", "removed-card", "reset-card", "server-too-busy", "sharing-violation", "system-cancelled", "unknown-reader", "unpowered-card", "unresponsive-card", "unsupported-card", "unsupported-feature" };
};
