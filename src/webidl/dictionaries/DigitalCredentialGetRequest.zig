//! WebIDL dictionary: DigitalCredentialGetRequest
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const DigitalCredentialGetRequest = struct {
    protocol: runtime.DOMString,
    data: v8.JSValue,
};
