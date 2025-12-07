//! WebIDL typedef: URLPatternInput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const URLPatternInput = union(enum) {
    usvstring: runtime.USVString,
    urlpattern_init: dictionaries.URLPatternInit,
};
