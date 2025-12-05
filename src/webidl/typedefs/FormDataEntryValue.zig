//! WebIDL typedef: FormDataEntryValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FormDataEntryValue = union(enum) {
    file: *runtime.Instance,
    usvstring: runtime.USVString,
};
