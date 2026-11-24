//! WebIDL dictionary: TaskSignalAnyInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const TaskSignalAnyInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    priority: ?typedefs.TaskPriorityOrTaskSignal = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "priority", .{ .string = "user-visible" } },
    };
};
