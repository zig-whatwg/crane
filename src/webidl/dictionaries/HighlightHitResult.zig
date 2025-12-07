//! WebIDL dictionary: HighlightHitResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const HighlightHitResult = struct {
    highlight: ?*runtime.Instance = null,
    ranges: ?[]const *runtime.Instance = null,
};
