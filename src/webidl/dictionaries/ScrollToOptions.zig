//! WebIDL dictionary: ScrollToOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ScrollOptions = @import("ScrollOptions.zig").ScrollOptions;

pub const ScrollToOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from ScrollOptions
    base: ScrollOptions,

    left: ?f64 = null,
    top: ?f64 = null,
};
