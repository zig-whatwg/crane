//! WebIDL enum: TaskPriority
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const TaskPriority = enum {
    _user_blocking_,
    _user_visible_,
    _background_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "user-blocking", "user-visible", "background" };
};
