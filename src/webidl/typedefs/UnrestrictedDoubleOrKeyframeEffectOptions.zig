//! WebIDL typedef: UnrestrictedDoubleOrKeyframeEffectOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const UnrestrictedDoubleOrKeyframeEffectOptions = union(enum) {
    double: f64,
    keyframe_effect_options: dictionaries.KeyframeEffectOptions,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "double", .kind = .numeric },
        .{ .field = "keyframe_effect_options", .kind = .dictionary },
    };
};
