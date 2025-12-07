//! WebIDL typedef: CSSUnparsedSegment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CSSUnparsedSegment = union(enum) {
    usvstring: runtime.USVString,
    cssvariable_reference_value: *runtime.Instance,
};
