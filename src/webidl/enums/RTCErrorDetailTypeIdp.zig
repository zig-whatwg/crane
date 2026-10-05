//! WebIDL enum: RTCErrorDetailTypeIdp
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCErrorDetailTypeIdp = enum {
    _idp_bad_script_failure_,
    _idp_execution_failure_,
    _idp_load_failure_,
    _idp_need_login_,
    _idp_timeout_,
    _idp_tls_failure_,
    _idp_token_expired_,
    _idp_token_invalid_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "idp-bad-script-failure", "idp-execution-failure", "idp-load-failure", "idp-need-login", "idp-timeout", "idp-tls-failure", "idp-token-expired", "idp-token-invalid" };
};
