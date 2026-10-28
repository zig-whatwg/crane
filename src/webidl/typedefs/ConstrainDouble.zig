//! WebIDL typedef: ConstrainDouble
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const ConstrainDouble = union(enum) {
    double: f64,
    constrain_double_range: dictionaries.ConstrainDoubleRange,

    /// WebIDL `double` and `float` arms (not `unrestricted`): a value one of
    /// them takes is a TypeError when NaN or infinite (3.2.5, 3.2.7, 3.2.25).
    pub const restricted_arms = .{"double"};
};
