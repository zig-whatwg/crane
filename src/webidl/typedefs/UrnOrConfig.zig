//! WebIDL typedef: UrnOrConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const UrnOrConfig = union(enum) {
    usvstring: runtime.USVString,
    fenced_frame_config: *runtime.Instance,
};
