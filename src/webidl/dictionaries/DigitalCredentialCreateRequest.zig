//! WebIDL dictionary: DigitalCredentialCreateRequest
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DigitalCredentialCreateRequest = struct {
    protocol: runtime.DOMString,
    data: runtime.JSValue,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"data"};
};
