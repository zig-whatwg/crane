//! WebIDL typedef: ConstrainULong
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const dictionaries = @import("dictionaries");

pub const ConstrainULong = union(enum) {
    ulong: u32,
    constrain_ulong_range: dictionaries.ConstrainULongRange,
};
