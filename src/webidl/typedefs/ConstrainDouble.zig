//! WebIDL typedef: ConstrainDouble
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const ConstrainDouble = union(enum) {
    double: f64,
    constrain_double_range: dictionaries.ConstrainDoubleRange,
};
