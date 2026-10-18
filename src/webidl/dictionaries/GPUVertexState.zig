//! WebIDL dictionary: GPUVertexState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUProgrammableStage = @import("GPUProgrammableStage.zig").GPUProgrammableStage;

pub const GPUVertexState = struct {
    // Inherited from GPUProgrammableStage
    base: GPUProgrammableStage,

    buffers: ?[]const runtime.JSValue = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "buffers", .empty_sequence },
    };
};
