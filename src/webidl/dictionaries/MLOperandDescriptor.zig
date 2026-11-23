//! WebIDL dictionary: MLOperandDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const MLOperandDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    dataType: enums.MLOperandDataType,
    shape: []const runtime.JSValue,
};
