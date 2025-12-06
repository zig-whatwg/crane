//! WebIDL typedef: LineAndPositionSetting
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Enum types use DOMString to avoid circular imports (WebIDL enums are strings)

const runtime = @import("runtime");

pub const LineAndPositionSetting = union(enum) {
    double: f64,
    auto_keyword: runtime.DOMString,
};
