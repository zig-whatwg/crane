//! WebIDL typedef: LineAndPositionSetting
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LineAndPositionSetting = union(enum) {
    double: f64,
    auto_keyword: enums.AutoKeyword,

    /// WebIDL `double` and `float` arms (not `unrestricted`): a value one of
    /// them takes is a TypeError when NaN or infinite (3.2.5, 3.2.7, 3.2.25).
    pub const restricted_arms = .{"double"};
};
