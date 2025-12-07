//! WebIDL dictionary: CredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const OTPCredentialRequestOptions = @import("OTPCredentialRequestOptions.zig").OTPCredentialRequestOptions;
const DigitalCredentialRequestOptions = @import("DigitalCredentialRequestOptions.zig").DigitalCredentialRequestOptions;
const PublicKeyCredentialRequestOptions = @import("PublicKeyCredentialRequestOptions.zig").PublicKeyCredentialRequestOptions;
const FederatedCredentialRequestOptions = @import("FederatedCredentialRequestOptions.zig").FederatedCredentialRequestOptions;
const IdentityCredentialRequestOptions = @import("IdentityCredentialRequestOptions.zig").IdentityCredentialRequestOptions;

pub const CredentialRequestOptions = struct {
    mediation: ?enums.CredentialMediationRequirement = null,
    signal: ?*runtime.Instance = null,
    digital: ?DigitalCredentialRequestOptions = null,
    publicKey: ?PublicKeyCredentialRequestOptions = null,
    identity: ?IdentityCredentialRequestOptions = null,
    otp: ?OTPCredentialRequestOptions = null,
    password: ?bool = null,
    federated: ?FederatedCredentialRequestOptions = null,
};
