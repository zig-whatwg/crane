//! WebIDL dictionary: ScrollIntoViewOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ScrollOptions = @import("ScrollOptions.zig").ScrollOptions;

pub const ScrollIntoViewOptions = struct {
    // Inherited from ScrollOptions
    base: ScrollOptions,

    block: ?*const anyopaque = null,
    @"inline": ?*const anyopaque = null,
    container: ?*const anyopaque = null,
};
