//! WebIDL dictionary: TaskPriorityChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const TaskPriorityChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    previousPriority: enums.TaskPriority,
};
