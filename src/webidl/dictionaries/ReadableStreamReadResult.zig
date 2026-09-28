//! WebIDL dictionary: ReadableStreamReadResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ReadableStreamReadResult = struct {
    value: ?runtime.JSValue = null,
    done: ?bool = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"value"};
};
