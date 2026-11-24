//! WebIDL typedef: AudioContextLatencyCategoryOrDouble
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const enums = @import("enums");

pub const AudioContextLatencyCategoryOrDouble = union(enum) {
    audio_context_latency_category: enums.AudioContextLatencyCategory,
    double: f64,

    /// WebIDL `double` and `float` arms (not `unrestricted`): a value one of
    /// them takes is a TypeError when NaN or infinite (3.2.5, 3.2.7, 3.2.25).
    pub const restricted_arms = .{"double"};

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "audio_context_latency_category", .kind = .enumeration },
        .{ .field = "double", .kind = .numeric },
    };
};
