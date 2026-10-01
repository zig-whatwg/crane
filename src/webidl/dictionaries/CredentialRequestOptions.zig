//! WebIDL dictionary: CredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const OTPCredentialRequestOptions = @import("OTPCredentialRequestOptions.zig").OTPCredentialRequestOptions;
const DigitalCredentialRequestOptions = @import("DigitalCredentialRequestOptions.zig").DigitalCredentialRequestOptions;
const FederatedCredentialRequestOptions = @import("FederatedCredentialRequestOptions.zig").FederatedCredentialRequestOptions;
const PublicKeyCredentialRequestOptions = @import("PublicKeyCredentialRequestOptions.zig").PublicKeyCredentialRequestOptions;
const IdentityCredentialRequestOptions = @import("IdentityCredentialRequestOptions.zig").IdentityCredentialRequestOptions;

pub const CredentialRequestOptions = struct {
    mediation: ?enums.CredentialMediationRequirement = null,
    signal: ?*runtime.Instance = null,
    password: ?bool = null,
    federated: ?FederatedCredentialRequestOptions = null,
    digital: ?DigitalCredentialRequestOptions = null,
    identity: ?IdentityCredentialRequestOptions = null,
    otp: ?OTPCredentialRequestOptions = null,
    publicKey: ?PublicKeyCredentialRequestOptions = null,
};
