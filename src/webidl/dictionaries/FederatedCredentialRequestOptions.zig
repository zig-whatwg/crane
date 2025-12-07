//! WebIDL dictionary: FederatedCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const FederatedCredentialRequestOptions = struct {
    providers: ?[]const runtime.USVString = null,
    protocols: ?[]const runtime.DOMString = null,
};
