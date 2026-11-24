//! WebIDL typedef: TaskPriorityOrTaskSignal
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const enums = @import("enums");

pub const TaskPriorityOrTaskSignal = union(enum) {
    task_priority: enums.TaskPriority,
    task_signal: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "task_priority", .kind = .enumeration },
        .{ .field = "task_signal", .kind = .{ .interface = "TaskSignal" } },
    };
};
