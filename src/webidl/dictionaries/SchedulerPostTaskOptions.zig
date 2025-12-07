//! WebIDL dictionary: SchedulerPostTaskOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const SchedulerPostTaskOptions = struct {
    signal: ?*runtime.Instance = null,
    priority: ?enums.TaskPriority = null,
    delay: ?u64 = null,
};
