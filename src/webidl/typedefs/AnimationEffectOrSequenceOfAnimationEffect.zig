//! WebIDL typedef: AnimationEffectOrSequenceOfAnimationEffect
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const AnimationEffectOrSequenceOfAnimationEffect = union(enum) {
    animation_effect: *runtime.Instance,
    animation_effect_sequence: []const *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "animation_effect", .kind = .{ .interface = "AnimationEffect" } },
        .{ .field = "animation_effect_sequence", .kind = .{ .sequence = "AnimationEffect" } },
    };
};
