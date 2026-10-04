//! WebIDL enum: SecurePaymentConfirmationAvailability
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const SecurePaymentConfirmationAvailability = enum {
    _available_,
    _unavailable_unknown_reason_,
    _unavailable_feature_not_enabled_,
    _unavailable_no_permission_policy_,
    _unavailable_no_user_verifying_platform_authenticator_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "available", "unavailable-unknown-reason", "unavailable-feature-not-enabled", "unavailable-no-permission-policy", "unavailable-no-user-verifying-platform-authenticator" };
};
