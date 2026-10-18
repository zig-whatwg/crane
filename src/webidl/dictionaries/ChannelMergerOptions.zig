//! WebIDL dictionary: ChannelMergerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const ChannelMergerOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    numberOfInputs: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "numberOfInputs", .{ .number = 6 } },
    };
};
