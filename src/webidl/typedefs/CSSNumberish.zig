//! WebIDL typedef: CSSNumberish
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CSSNumberish = union(enum) {
    double: f64,
    cssnumeric_value: *runtime.Instance,
};
