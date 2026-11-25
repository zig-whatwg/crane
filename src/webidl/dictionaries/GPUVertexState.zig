//! WebIDL dictionary: GPUVertexState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUVertexBufferLayout = @import("GPUVertexBufferLayout.zig").GPUVertexBufferLayout;
const GPUProgrammableStage = @import("GPUProgrammableStage.zig").GPUProgrammableStage;

pub const GPUVertexState = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from GPUProgrammableStage
    base: GPUProgrammableStage,

    buffers: ?[]const ?GPUVertexBufferLayout = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "buffers", .empty_sequence },
    };
};
