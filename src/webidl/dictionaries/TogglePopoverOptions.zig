//! WebIDL dictionary: TogglePopoverOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ShowPopoverOptions = @import("ShowPopoverOptions.zig").ShowPopoverOptions;

pub const TogglePopoverOptions = struct {
    // Inherited from ShowPopoverOptions
    base: ShowPopoverOptions,

    force: ?bool = null,
};
