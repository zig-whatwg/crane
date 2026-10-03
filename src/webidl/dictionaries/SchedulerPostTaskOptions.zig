//! WebIDL dictionary: SchedulerPostTaskOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const SchedulerPostTaskOptions = struct {
    signal: ?*runtime.Instance = null,
    priority: ?enums.TaskPriority = null,
    delay: ?u64 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"delay"};
};
