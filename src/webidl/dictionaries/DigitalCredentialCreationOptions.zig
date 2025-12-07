//! WebIDL dictionary: DigitalCredentialCreationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const DigitalCredentialCreateRequest = @import("DigitalCredentialCreateRequest.zig").DigitalCredentialCreateRequest;

pub const DigitalCredentialCreationOptions = struct {
    requests: ?[]const DigitalCredentialCreateRequest = null,
};
