//! WebIDL enum: RTCErrorDetailType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCErrorDetailType = enum {
    _data_channel_failure_,
    _dtls_failure_,
    _fingerprint_failure_,
    _sctp_failure_,
    _sdp_syntax_error_,
    _hardware_encoder_not_available_,
    _hardware_encoder_error_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "data-channel-failure", "dtls-failure", "fingerprint-failure", "sctp-failure", "sdp-syntax-error", "hardware-encoder-not-available", "hardware-encoder-error" };
};
