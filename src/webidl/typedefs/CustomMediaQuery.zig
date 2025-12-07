//! WebIDL typedef: CustomMediaQuery
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const CustomMediaQuery = union(enum) {
    media_list: *runtime.Instance,
    boolean: bool,
};
