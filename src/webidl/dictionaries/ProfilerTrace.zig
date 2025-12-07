//! WebIDL dictionary: ProfilerTrace
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ProfilerStack = @import("ProfilerStack.zig").ProfilerStack;
const ProfilerFrame = @import("ProfilerFrame.zig").ProfilerFrame;
const ProfilerSample = @import("ProfilerSample.zig").ProfilerSample;

pub const ProfilerTrace = struct {
    resources: []const typedefs.ProfilerResource,
    frames: []const ProfilerFrame,
    stacks: []const ProfilerStack,
    samples: []const ProfilerSample,
};
