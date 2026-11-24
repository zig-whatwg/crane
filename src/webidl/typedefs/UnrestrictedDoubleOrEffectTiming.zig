//! WebIDL typedef: UnrestrictedDoubleOrEffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const UnrestrictedDoubleOrEffectTiming = union(enum) {
    double: f64,
    effect_timing: dictionaries.EffectTiming,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "double", .kind = .numeric },
        .{ .field = "effect_timing", .kind = .dictionary },
    };
};
