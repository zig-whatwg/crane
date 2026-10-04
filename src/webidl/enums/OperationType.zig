//! WebIDL enum: OperationType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const OperationType = enum {
    _token_request_,
    _send_redemption_record_,
    _token_redemption_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "token-request", "send-redemption-record", "token-redemption" };
};
