//! WebIDL dictionary: PublicKeyCredentialRequestOptionsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const PublicKeyCredentialDescriptorJSON = @import("PublicKeyCredentialDescriptorJSON.zig").PublicKeyCredentialDescriptorJSON;
const AuthenticationExtensionsClientInputsJSON = @import("AuthenticationExtensionsClientInputsJSON.zig").AuthenticationExtensionsClientInputsJSON;

pub const PublicKeyCredentialRequestOptionsJSON = struct {
    challenge: typedefs.Base64URLString,
    timeout: ?u32 = null,
    rpId: ?runtime.DOMString = null,
    allowCredentials: ?[]const PublicKeyCredentialDescriptorJSON = null,
    userVerification: ?runtime.DOMString = null,
    hints: ?[]const runtime.DOMString = null,
    extensions: ?AuthenticationExtensionsClientInputsJSON = null,
};
