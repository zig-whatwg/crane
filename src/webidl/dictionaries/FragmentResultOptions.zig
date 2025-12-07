//! WebIDL dictionary: FragmentResultOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const BreakTokenOptions = @import("BreakTokenOptions.zig").BreakTokenOptions;

pub const FragmentResultOptions = struct {
    inlineSize: ?f64 = null,
    blockSize: ?f64 = null,
    autoBlockSize: ?f64 = null,
    childFragments: ?[]const *runtime.Instance = null,
    data: ?v8.JSValue = null,
    breakToken: ?BreakTokenOptions = null,
};
