//! WebIDL dictionary: ScrollIntoViewOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const ScrollOptions = @import("ScrollOptions.zig").ScrollOptions;

pub const ScrollIntoViewOptions = struct {
    // Inherited from ScrollOptions
    base: ScrollOptions,

    block: ?enums.ScrollLogicalPosition = null,
    @"inline": ?enums.ScrollLogicalPosition = null,
    container: ?enums.ScrollIntoViewContainer = null,
};
