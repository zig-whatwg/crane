//! WebIDL typedef: URLPatternInput
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const URLPatternInput = union(enum) {
    usvstring: runtime.USVString,
    urlpattern_init: *runtime.Instance,
};
