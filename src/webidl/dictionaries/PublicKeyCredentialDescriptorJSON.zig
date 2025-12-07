//! WebIDL dictionary: PublicKeyCredentialDescriptorJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const PublicKeyCredentialDescriptorJSON = struct {
    @"type": runtime.DOMString,
    id: typedefs.Base64URLString,
    transports: ?[]const runtime.DOMString = null,
};
