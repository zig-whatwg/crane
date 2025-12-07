//! WebIDL dictionary: GlobalDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GlobalDescriptor = struct {
    value: enums.ValueType,
    mutable: ?bool = null,
};
