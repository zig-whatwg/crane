//! WebIDL dictionary: MLOperandDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const MLOperandDescriptor = struct {
    dataType: enums.MLOperandDataType,
    shape: []const runtime.JSValue,
};
