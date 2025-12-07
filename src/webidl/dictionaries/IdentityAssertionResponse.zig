//! WebIDL dictionary: IdentityAssertionResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const IdentityCredentialErrorInit = @import("IdentityCredentialErrorInit.zig").IdentityCredentialErrorInit;

pub const IdentityAssertionResponse = struct {
    token: ?v8.JSValue = null,
    continue_on: ?runtime.USVString = null,
    @"error": ?IdentityCredentialErrorInit = null,
};
