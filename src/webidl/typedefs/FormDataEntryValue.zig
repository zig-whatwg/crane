//! WebIDL typedef: FormDataEntryValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FormDataEntryValue = union(enum) {
    variant_0: *const anyopaque,
    variant_1: runtime.USVString,
};
