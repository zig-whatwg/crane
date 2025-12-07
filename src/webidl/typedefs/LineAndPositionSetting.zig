//! WebIDL typedef: LineAndPositionSetting
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LineAndPositionSetting = union(enum) {
    double: f64,
    auto_keyword: enums.AutoKeyword,
};
