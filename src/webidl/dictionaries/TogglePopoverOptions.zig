//! WebIDL dictionary: TogglePopoverOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ShowPopoverOptions = @import("ShowPopoverOptions.zig").ShowPopoverOptions;

pub const TogglePopoverOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from ShowPopoverOptions
    base: ShowPopoverOptions,

    force: ?bool = null,
};
