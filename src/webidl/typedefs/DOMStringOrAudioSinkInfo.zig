//! WebIDL typedef: DOMStringOrAudioSinkInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DOMStringOrAudioSinkInfo = union(enum) {
    domstring: runtime.DOMString,
    audio_sink_info: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "audio_sink_info", .kind = .{ .interface = "AudioSinkInfo" } },
    };
};
