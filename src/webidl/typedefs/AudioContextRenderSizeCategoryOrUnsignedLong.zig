//! WebIDL typedef: AudioContextRenderSizeCategoryOrUnsignedLong
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const enums = @import("enums");

pub const AudioContextRenderSizeCategoryOrUnsignedLong = union(enum) {
    audio_context_render_size_category: enums.AudioContextRenderSizeCategory,
    ulong: u32,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "audio_context_render_size_category", .kind = .enumeration },
        .{ .field = "ulong", .kind = .numeric },
    };
};
