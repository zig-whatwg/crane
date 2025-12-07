//! WebIDL typedef: CustomMediaQuery
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CustomMediaQuery = union(enum) {
    media_list: *runtime.Instance,
    boolean: bool,
};
