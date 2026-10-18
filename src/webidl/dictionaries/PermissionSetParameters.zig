//! WebIDL dictionary: PermissionSetParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const PermissionSetParameters = struct {
    descriptor: runtime.JSValue,
    state: enums.PermissionState,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"descriptor"};
};
