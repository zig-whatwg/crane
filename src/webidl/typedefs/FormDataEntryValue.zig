//! WebIDL typedef: FormDataEntryValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const FormDataEntryValue = union(enum) {
    file: *runtime.Instance,
    usvstring: runtime.USVString,
};
