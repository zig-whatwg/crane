//! WebIDL dictionary: IdentityAssertionResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IdentityAssertionResponse = struct {
    token: ?*const anyopaque = null,
    continue_on: ?runtime.USVString = null,
    @"error": ?*const anyopaque = null,
};
