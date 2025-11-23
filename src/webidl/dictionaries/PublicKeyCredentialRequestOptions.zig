//! WebIDL dictionary: PublicKeyCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PublicKeyCredentialRequestOptions = struct {
    challenge: *const anyopaque,
    timeout: ?u32 = null,
    rpId: ?runtime.DOMString = null,
    allowCredentials: ?*const anyopaque = null,
    userVerification: ?runtime.DOMString = null,
    hints: ?*const anyopaque = null,
    extensions: ?*const anyopaque = null,
};
