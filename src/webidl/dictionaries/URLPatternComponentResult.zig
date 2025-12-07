//! WebIDL dictionary: URLPatternComponentResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const URLPatternComponentResult = struct {
    input: ?runtime.USVString = null,
    groups: ?[]const struct { key: runtime.USVString, value: *const anyopaque } = null,
};
