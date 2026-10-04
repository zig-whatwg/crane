//! WebIDL enum: ClientCapability
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ClientCapability = enum {
    _conditionalCreate_,
    _conditionalGet_,
    _hybridTransport_,
    _passkeyPlatformAuthenticator_,
    _userVerifyingPlatformAuthenticator_,
    _relatedOrigins_,
    _signalAllAcceptedCredentials_,
    _signalCurrentUserDetails_,
    _signalUnknownCredential_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "conditionalCreate", "conditionalGet", "hybridTransport", "passkeyPlatformAuthenticator", "userVerifyingPlatformAuthenticator", "relatedOrigins", "signalAllAcceptedCredentials", "signalCurrentUserDetails", "signalUnknownCredential" };
};
