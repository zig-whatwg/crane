//! WebIDL dictionary: PublicKeyCredentialDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const PublicKeyCredentialDescriptor = struct {
    @"type": runtime.DOMString,
    id: typedefs.BufferSource,
    transports: ?[]const runtime.DOMString = null,
};
