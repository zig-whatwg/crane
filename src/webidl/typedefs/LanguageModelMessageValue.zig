//! WebIDL typedef: LanguageModelMessageValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const LanguageModelMessageValue = union(enum) {
    image_bitmap_source: typedefs.ImageBitmapSource,
    audio_buffer: *runtime.Instance,
    buffer_source: typedefs.BufferSource,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "image_bitmap_source", .kind = .@"union" },
        .{ .field = "audio_buffer", .kind = .{ .interface = "AudioBuffer" } },
        .{ .field = "buffer_source", .kind = .buffer_source },
        .{ .field = "domstring", .kind = .string },
    };
};
