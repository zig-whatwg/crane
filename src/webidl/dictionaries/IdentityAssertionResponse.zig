//! WebIDL dictionary: IdentityAssertionResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const IdentityCredentialErrorInit = @import("IdentityCredentialErrorInit.zig").IdentityCredentialErrorInit;

pub const IdentityAssertionResponse = struct {
    token: ?runtime.JSValue = null,
    continue_on: ?runtime.USVString = null,
    @"error": ?IdentityCredentialErrorInit = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"token"};
};
