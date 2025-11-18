//! WebIDL dictionary: PublicKeyCredentialRequestOptionsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PublicKeyCredentialRequestOptionsJSON = struct {
    challenge: anyopaque,
    timeout: ?u32 = null,
    rpId: ?runtime.DOMString = null,
    allowCredentials: ?anyopaque = null,
    userVerification: ?runtime.DOMString = null,
    hints: ?anyopaque = null,
    extensions: ?anyopaque = null,
};
