//! WebIDL typedef: URLPatternCompatible
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const dictionaries = @import("dictionaries");

pub const URLPatternCompatible = union(enum) {
    usvstring: runtime.USVString,
    urlpattern_init: dictionaries.URLPatternInit,
    urlpattern: *runtime.Instance,
};
