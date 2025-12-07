//! WebIDL dictionary: PublicKeyCredentialCreationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AuthenticationExtensionsClientInputs = @import("AuthenticationExtensionsClientInputs.zig").AuthenticationExtensionsClientInputs;
const PublicKeyCredentialRpEntity = @import("PublicKeyCredentialRpEntity.zig").PublicKeyCredentialRpEntity;
const PublicKeyCredentialUserEntity = @import("PublicKeyCredentialUserEntity.zig").PublicKeyCredentialUserEntity;
const PublicKeyCredentialParameters = @import("PublicKeyCredentialParameters.zig").PublicKeyCredentialParameters;
const PublicKeyCredentialDescriptor = @import("PublicKeyCredentialDescriptor.zig").PublicKeyCredentialDescriptor;
const AuthenticatorSelectionCriteria = @import("AuthenticatorSelectionCriteria.zig").AuthenticatorSelectionCriteria;

pub const PublicKeyCredentialCreationOptions = struct {
    rp: PublicKeyCredentialRpEntity,
    user: PublicKeyCredentialUserEntity,
    challenge: typedefs.BufferSource,
    pubKeyCredParams: []const PublicKeyCredentialParameters,
    timeout: ?u32 = null,
    excludeCredentials: ?[]const PublicKeyCredentialDescriptor = null,
    authenticatorSelection: ?AuthenticatorSelectionCriteria = null,
    hints: ?[]const runtime.DOMString = null,
    attestation: ?runtime.DOMString = null,
    attestationFormats: ?[]const runtime.DOMString = null,
    extensions: ?AuthenticationExtensionsClientInputs = null,
};
