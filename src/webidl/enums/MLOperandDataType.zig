//! WebIDL enum: MLOperandDataType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const MLOperandDataType = enum {
    _float32_,
    _float16_,
    _int32_,
    _uint32_,
    _int64_,
    _uint64_,
    _int8_,
    _uint8_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "float32", "float16", "int32", "uint32", "int64", "uint64", "int8", "uint8" };
};
