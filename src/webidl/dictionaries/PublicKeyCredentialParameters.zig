//! WebIDL dictionary: PublicKeyCredentialParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PublicKeyCredentialParameters = struct {
    @"type": runtime.DOMString,
    alg: typedefs.COSEAlgorithmIdentifier,
};
