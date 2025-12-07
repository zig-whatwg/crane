//! WebIDL dictionary: CredentialCreationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const DigitalCredentialCreationOptions = @import("DigitalCredentialCreationOptions.zig").DigitalCredentialCreationOptions;
const PublicKeyCredentialCreationOptions = @import("PublicKeyCredentialCreationOptions.zig").PublicKeyCredentialCreationOptions;
const FederatedCredentialInit = @import("FederatedCredentialInit.zig").FederatedCredentialInit;

pub const CredentialCreationOptions = struct {
    mediation: ?enums.CredentialMediationRequirement = null,
    signal: ?*runtime.Instance = null,
    digital: ?DigitalCredentialCreationOptions = null,
    publicKey: ?PublicKeyCredentialCreationOptions = null,
    password: ?typedefs.PasswordCredentialInit = null,
    federated: ?FederatedCredentialInit = null,
};
