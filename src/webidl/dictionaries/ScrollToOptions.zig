//! WebIDL dictionary: ScrollToOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const ScrollOptions = @import("ScrollOptions.zig").ScrollOptions;

pub const ScrollToOptions = struct {
    // Inherited from ScrollOptions
    base: ScrollOptions,

    left: ?f64 = null,
    top: ?f64 = null,
};
