//! WebIDL dictionary: PermissionSetParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const PermissionSetParameters = struct {
    descriptor: v8.JSValue,
    state: enums.PermissionState,
};
