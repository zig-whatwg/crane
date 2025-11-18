//! WebIDL dictionary: ScrollIntoViewOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ScrollOptions = @import("ScrollOptions.zig").ScrollOptions;

pub const ScrollIntoViewOptions = struct {
    // Inherited from ScrollOptions
    base: ScrollOptions,

    block: ?anyopaque = null,
    inline: ?anyopaque = null,
    container: ?anyopaque = null,
};
