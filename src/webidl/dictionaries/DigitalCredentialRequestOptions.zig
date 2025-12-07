//! WebIDL dictionary: DigitalCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const DigitalCredentialGetRequest = @import("DigitalCredentialGetRequest.zig").DigitalCredentialGetRequest;

pub const DigitalCredentialRequestOptions = struct {
    requests: []const DigitalCredentialGetRequest,
};
