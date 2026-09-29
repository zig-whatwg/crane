//! WebIDL dictionary: BreakTokenOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BreakTokenOptions = struct {
    childBreakTokens: ?[]const *runtime.Instance = null,
    data: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"data"};
};
