//! WebIDL typedef: CSSUnparsedSegment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const CSSUnparsedSegment = union(enum) {
    usvstring: runtime.USVString,
    cssvariable_reference_value: *runtime.Instance,
};
