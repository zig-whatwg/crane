//! WebIDL dictionary: ProfilerFrame
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ProfilerFrame = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    name: runtime.DOMString,
    resourceId: ?u64 = null,
    line: ?u64 = null,
    column: ?u64 = null,
};
