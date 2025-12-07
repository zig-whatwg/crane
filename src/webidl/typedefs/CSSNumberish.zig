//! WebIDL typedef: CSSNumberish
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const CSSNumberish = union(enum) {
    double: f64,
    cssnumeric_value: *runtime.Instance,
};
