//! WebIDL dictionary: RouterRule
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const RouterCondition = @import("RouterCondition.zig").RouterCondition;

pub const RouterRule = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    condition: RouterCondition,
    source: typedefs.RouterSource,
};
