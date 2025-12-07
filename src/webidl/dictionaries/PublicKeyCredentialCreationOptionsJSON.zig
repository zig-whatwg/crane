//! WebIDL dictionary: PublicKeyCredentialCreationOptionsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const PublicKeyCredentialUserEntityJSON = @import("PublicKeyCredentialUserEntityJSON.zig").PublicKeyCredentialUserEntityJSON;
const PublicKeyCredentialRpEntity = @import("PublicKeyCredentialRpEntity.zig").PublicKeyCredentialRpEntity;
const PublicKeyCredentialDescriptorJSON = @import("PublicKeyCredentialDescriptorJSON.zig").PublicKeyCredentialDescriptorJSON;
const PublicKeyCredentialParameters = @import("PublicKeyCredentialParameters.zig").PublicKeyCredentialParameters;
const AuthenticatorSelectionCriteria = @import("AuthenticatorSelectionCriteria.zig").AuthenticatorSelectionCriteria;
const AuthenticationExtensionsClientInputsJSON = @import("AuthenticationExtensionsClientInputsJSON.zig").AuthenticationExtensionsClientInputsJSON;

pub const PublicKeyCredentialCreationOptionsJSON = struct {
    rp: PublicKeyCredentialRpEntity,
    user: PublicKeyCredentialUserEntityJSON,
    challenge: typedefs.Base64URLString,
    pubKeyCredParams: []const PublicKeyCredentialParameters,
    timeout: ?u32 = null,
    excludeCredentials: ?[]const PublicKeyCredentialDescriptorJSON = null,
    authenticatorSelection: ?AuthenticatorSelectionCriteria = null,
    hints: ?[]const runtime.DOMString = null,
    attestation: ?runtime.DOMString = null,
    attestationFormats: ?[]const runtime.DOMString = null,
    extensions: ?AuthenticationExtensionsClientInputsJSON = null,
};
