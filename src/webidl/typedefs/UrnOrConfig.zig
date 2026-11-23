//! WebIDL typedef: UrnOrConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const UrnOrConfig = union(enum) {
    usvstring: runtime.USVString,
    fenced_frame_config: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "usvstring", .kind = .string },
        .{ .field = "fenced_frame_config", .kind = .{ .interface = "FencedFrameConfig" } },
    };
};
