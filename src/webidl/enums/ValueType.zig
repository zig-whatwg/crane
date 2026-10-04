//! WebIDL enum: ValueType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ValueType = enum {
    _i32_,
    _i64_,
    _f32_,
    _f64_,
    _v128_,
    _externref_,
    _anyfunc_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "i32", "i64", "f32", "f64", "v128", "externref", "anyfunc" };
};
